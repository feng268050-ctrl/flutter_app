import 'dart:async';

import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/ethernet_controller.dart';
import 'package:cyber_hal/src/network/ethernet_models.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/wifi_controller.dart';
import 'package:cyber_hal/src/network/wifi_models.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

/// One L3 path ranked for default-route preference (lower [routeMetric] wins).
class RankedNetworkPath {
  const RankedNetworkPath({
    required this.role,
    required this.iface,
    required this.routeMetric,
  });

  final NetRole role;
  final String iface;

  /// systemd-networkd RouteMetric (lower = preferred for internet / DNS).
  final int routeMetric;

  @override
  String toString() =>
      'RankedNetworkPath($role → $iface metric=$routeMetric)';
}

/// Product-owned primary uplink preference (not board hardware).
///
/// Same motherboard may ship in products that use Wi‑Fi or Ethernet as the
/// internet path. Persist under `/var/lib/network/primary.conf`.
abstract final class PrimaryNetworkPrefs {
  static const confPath = '/var/lib/network/primary.conf';
  static const keyRole = 'role';

  /// RouteMetric applied to the product-chosen primary iface.
  static const preferredMetric = 100;

  /// RouteMetric applied to non-primary ifaces (e.g. camera LAN).
  static const secondaryMetric = 2000;

  static NetRole? roleFromToken(String? raw) {
    final token = (raw ?? '').trim();
    if (token.isEmpty) {
      return null;
    }
    return NetRole.tryParse(token);
  }

  static String tokenFor(NetRole role) => role.id;

  static NetRole? readRoleSync([String path = confPath]) {
    final map = readKeyValueConfFileSync(path);
    return roleFromToken(map[keyRole]);
  }

  static Future<NetRole?> readRole([String path = confPath]) async {
    final map = await readKeyValueConfFile(path);
    return roleFromToken(map[keyRole]);
  }

  static Future<void> writeRole(NetRole role, [String path = confPath]) {
    return upsertKeyValueConfFile(path, {keyRole: tokenFor(role)});
  }
}

/// Resolves effective RouteMetric with optional product primary override.
abstract final class PrimaryNetworkPolicy {
  /// [productPrimary] when non-null wins; otherwise read sync pref, else board.
  static int effectiveMetric({
    required String iface,
    required NetRole role,
    BoardProfile? profile,
    NetRole? productPrimary,
    Map<String, int>? routeMetrics,
    String prefPath = PrimaryNetworkPrefs.confPath,
  }) {
    final primary =
        productPrimary ?? PrimaryNetworkPrefs.readRoleSync(prefPath);
    if (primary != null) {
      return role == primary
          ? PrimaryNetworkPrefs.preferredMetric
          : PrimaryNetworkPrefs.secondaryMetric;
    }
    return routeMetrics?[iface] ??
        profile?.routeMetricFor(iface) ??
        NetworkdIpv4Apply.defaultRouteMetric(iface);
  }
}

/// Product API: get/set which [NetRole] is the internet-preferred uplink.
abstract class PrimaryNetworkController {
  /// Cached primary after [load] / [setPrimaryRole] (null = board metric order).
  RankedNetworkPath? get currentPrimary;

  NetRole? get currentPrimaryRole;

  /// Fires after [load] (if a role was set) and after each [setPrimaryRole].
  Stream<RankedNetworkPath?> get primaryChanges;

  /// Read preference into cache (call on bring-up).
  Future<void> load();

  Future<NetRole?> getPrimaryRole();

  Future<RankedNetworkPath?> getPrimary();

  /// Product chooses the internet uplink. Persists and re-applies RouteMetric.
  Future<void> setPrimaryRole(NetRole role);

  /// All known role→iface paths sorted by effective RouteMetric (primary first).
  List<RankedNetworkPath> rankedPaths();

  Future<void> dispose();
}

/// Linux: `/var/lib/network/primary.conf` + networkd RouteMetric re-apply.
final class LinuxPrimaryNetworkController implements PrimaryNetworkController {
  LinuxPrimaryNetworkController({
    required this.profile,
    this.preferencePath = PrimaryNetworkPrefs.confPath,
    this.wifi,
    this.ethernet,
    this.roles = NetRole.values,
    NetworkdIpv4Apply? apply,
  }) : _apply = apply ?? NetworkdIpv4Apply();

  final BoardProfile profile;
  final String preferencePath;
  final WifiController? wifi;
  final EthernetController? ethernet;
  final Iterable<NetRole> roles;
  final NetworkdIpv4Apply _apply;

  final _changes = StreamController<RankedNetworkPath?>.broadcast();
  NetRole? _productPrimary;

  @override
  RankedNetworkPath? get currentPrimary {
    final paths = rankedPaths();
    if (paths.isEmpty) {
      return null;
    }
    return paths.first;
  }

  @override
  NetRole? get currentPrimaryRole => currentPrimary?.role;

  @override
  Stream<RankedNetworkPath?> get primaryChanges => _changes.stream;

  @override
  Future<void> load() async {
    _productPrimary = await PrimaryNetworkPrefs.readRole(preferencePath);
    if (!_changes.isClosed) {
      _changes.add(currentPrimary);
    }
    lwsTrace(
      'network: primary load → ${_productPrimary?.id ?? "(board metrics)"}',
    );
  }

  @override
  Future<NetRole?> getPrimaryRole() async {
    _productPrimary ??= await PrimaryNetworkPrefs.readRole(preferencePath);
    return _productPrimary;
  }

  @override
  Future<RankedNetworkPath?> getPrimary() async {
    await load();
    return currentPrimary;
  }

  @override
  Future<void> setPrimaryRole(NetRole role) async {
    final iface = profile.ifaceFor(role)?.trim();
    if (iface == null || iface.isEmpty) {
      throw StateError('board profile has no iface for $role');
    }
    await PrimaryNetworkPrefs.writeRole(role, preferencePath);
    _productPrimary = role;
    await _applyRouteMetrics();
    if (!_changes.isClosed) {
      _changes.add(currentPrimary);
    }
    lwsTrace('network: primary → ${role.id} ($iface)');
  }

  @override
  List<RankedNetworkPath> rankedPaths() {
    final out = <RankedNetworkPath>[];
    for (final role in roles) {
      final iface = profile.ifaceFor(role)?.trim();
      if (iface == null || iface.isEmpty) {
        continue;
      }
      out.add(RankedNetworkPath(
        role: role,
        iface: iface,
        routeMetric: PrimaryNetworkPolicy.effectiveMetric(
          iface: iface,
          role: role,
          profile: profile,
          productPrimary: _productPrimary,
          routeMetrics: profile.routeMetrics,
          prefPath: preferencePath,
        ),
      ));
    }
    out.sort((a, b) {
      final byMetric = a.routeMetric.compareTo(b.routeMetric);
      if (byMetric != 0) {
        return byMetric;
      }
      return a.iface.compareTo(b.iface);
    });
    return out;
  }

  Future<void> _applyRouteMetrics() async {
    final wifiCtrl = wifi;
    if (wifiCtrl != null) {
      await _reapplyWifi(wifiCtrl);
    }
    final ethCtrl = ethernet;
    if (ethCtrl != null) {
      await _reapplyEthernet(ethCtrl);
    }
  }

  Future<void> _reapplyWifi(WifiController wifiCtrl) async {
    final iface = wifiCtrl.interfaceName;
    final metric = PrimaryNetworkPolicy.effectiveMetric(
      iface: iface,
      role: NetRole.wifiStation,
      profile: profile,
      productPrimary: _productPrimary,
      routeMetrics: profile.routeMetrics,
      prefPath: preferencePath,
    );
    try {
      final cfg = await wifiCtrl.getIpv4Config();
      if (cfg.mode == WlanIpv4Mode.dhcp) {
        await _apply.apply(
          iface: iface,
          mode: 'dhcp',
          routeMetric: metric,
        );
      } else {
        await _apply.apply(
          iface: iface,
          mode: 'static',
          routeMetric: metric,
          address: cfg.address,
          prefix: '${cfg.prefixLength}',
          gateway: cfg.gateway.isNotEmpty ? cfg.gateway : null,
          dns: cfg.dns.isNotEmpty ? cfg.dns : null,
        );
      }
    } catch (e) {
      lwsTrace('network: primary reapply wifi failed: $e');
    }
  }

  Future<void> _reapplyEthernet(EthernetController ethCtrl) async {
    final iface = ethCtrl.interfaceName;
    final metric = PrimaryNetworkPolicy.effectiveMetric(
      iface: iface,
      role: NetRole.ethernetPrimary,
      profile: profile,
      productPrimary: _productPrimary,
      routeMetrics: profile.routeMetrics,
      prefPath: preferencePath,
    );
    try {
      final cfg = await ethCtrl.getIpv4Config();
      if (cfg.mode == EthIpv4Mode.dhcp) {
        await _apply.apply(
          iface: iface,
          mode: 'dhcp',
          routeMetric: metric,
        );
      } else {
        await _apply.apply(
          iface: iface,
          mode: 'static',
          routeMetric: metric,
          address: cfg.address,
          prefix: '${cfg.prefixLength}',
          gateway: cfg.gateway.isNotEmpty ? cfg.gateway : null,
          dns: cfg.dns.isNotEmpty ? cfg.dns : null,
        );
      }
    } catch (e) {
      lwsTrace('network: primary reapply ethernet failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
  }
}

/// Board-metric ranking when no [LinuxPrimaryNetworkController] is wired.
/// Prefer [PrimaryNetworkController] for product get/set.
final class PrimaryNetworkResolver {
  PrimaryNetworkResolver({
    required this.profile,
    this.roles = NetRole.values,
    this.preferencePath = PrimaryNetworkPrefs.confPath,
  });

  final BoardProfile profile;
  final Iterable<NetRole> roles;
  final String preferencePath;

  static int metricForIface(BoardProfile profile, String iface) {
    return profile.routeMetricFor(iface) ??
        NetworkdIpv4Apply.defaultRouteMetric(iface);
  }

  int metricFor(String iface) => metricForIface(profile, iface);

  List<RankedNetworkPath> rankedPaths() {
    final out = <RankedNetworkPath>[];
    for (final role in roles) {
      final iface = profile.ifaceFor(role)?.trim();
      if (iface == null || iface.isEmpty) {
        continue;
      }
      out.add(RankedNetworkPath(
        role: role,
        iface: iface,
        routeMetric: PrimaryNetworkPolicy.effectiveMetric(
          iface: iface,
          role: role,
          profile: profile,
          routeMetrics: profile.routeMetrics,
          prefPath: preferencePath,
        ),
      ));
    }
    out.sort((a, b) {
      final byMetric = a.routeMetric.compareTo(b.routeMetric);
      if (byMetric != 0) {
        return byMetric;
      }
      return a.iface.compareTo(b.iface);
    });
    return out;
  }

  RankedNetworkPath? get primary {
    final paths = rankedPaths();
    if (paths.isEmpty) {
      return null;
    }
    return paths.first;
  }

  NetRole? get primaryRole => primary?.role;

  String? get primaryIface => primary?.iface;
}
