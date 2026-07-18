import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/ethernet_controller.dart';
import 'package:cyber_hal/src/network/ethernet_models.dart';
import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/wifi_link_parse.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Linux wired Ethernet session: Streams + networkd D-Bus status / apply.
///
/// Prefer constructing via [BoardBindings.ethernetSession].
class LinuxEthernetSession implements EthernetController {
  LinuxEthernetSession({
    this.profile,
    String? iface,
    String? ipv4Path,
    String? ethWantedPath,
    Map<String, int>? routeMetrics,
    this.prefRoot = '/var/lib/network',
  })  : iface = iface ??
            profile?.ifaceFor(NetRole.ethernetPrimary) ??
            'eth0',
        _routeMetrics = routeMetrics ?? profile?.routeMetrics ?? const {},
        ipv4Path = ipv4Path ??
            EthIpv4Store.pathFor(
              iface ?? profile?.ifaceFor(NetRole.ethernetPrimary) ?? 'eth0',
              prefRoot: prefRoot,
            ),
        ethWantedPath = ethWantedPath ??
            EthIpv4Store.wantedPathFor(
              iface ?? profile?.ifaceFor(NetRole.ethernetPrimary) ?? 'eth0',
              prefRoot: prefRoot,
            );

  final BoardProfile? profile;
  final String iface;
  final String ipv4Path;
  final String ethWantedPath;
  final String prefRoot;
  final Map<String, int> _routeMetrics;

  @override
  String get interfaceName => iface;

  final _adminCtrl = StreamController<EthAdminState>.broadcast();
  final _linkCtrl = StreamController<EthLinkState>.broadcast();

  EthAdminState _admin = EthAdminState.off;
  EthLinkState _link = EthLinkState.down;
  Timer? _wantedTimeout;
  int _wantedTicks = 0;

  DBusClient? _bus;
  NetworkdDbus? _netdDbus;

  static const _wantedWatchMaxTicks = 120;

  int get _metric =>
      _routeMetrics[iface] ??
      profile?.routeMetricFor(iface) ??
      NetworkdIpv4Apply.defaultRouteMetric(iface);

  @override
  EthAdminState get currentAdmin => _admin;

  @override
  EthLinkState get currentLink => _link;

  @override
  Stream<EthAdminState> get admin => _adminCtrl.stream;

  @override
  Stream<EthLinkState> get link => _linkCtrl.stream;

  Map<String, String> get _env => {
        ...Platform.environment,
        'LWS_ETH_IFACE': iface,
      };

  void _emitAdmin(EthAdminState s) {
    _admin = s;
    if (!_adminCtrl.isClosed) {
      _adminCtrl.add(s);
    }
  }

  void _emitLink(EthLinkState s) {
    _link = s;
    if (!_linkCtrl.isClosed) {
      _linkCtrl.add(s);
    }
  }

  Future<void> _ensureDbus() async {
    if (_bus != null) {
      return;
    }
    _bus = DBusClient.system();
    _netdDbus = NetworkdDbus(client: _bus);
  }

  Future<ProcessResult> _run(List<String> cmd, {bool log = true}) async {
    if (cmd.isEmpty) {
      return ProcessResult(0, 1, '', 'empty command');
    }
    if (log) {
      lwsTrace('ethernet[$iface]: ${cmd.join(' ')}');
    }
    return Process.run(cmd.first, cmd.sublist(1), environment: _env);
  }

  Future<void> _startStatusWatch() async {
    await _ensureDbus();
    await _netdDbus!.watchLink(iface, onChange: () {
      unawaited(_refreshStatus());
    });
  }

  Future<void> _stopStatusWatch() async {
    await _netdDbus?.cancelWatch();
  }

  void _stopWantedWatch() {
    _wantedTimeout?.cancel();
    _wantedTimeout = null;
    _wantedTicks = 0;
  }

  void _startWantedWatch() {
    _stopWantedWatch();
    unawaited(() async {
      try {
        await _ensureDbus();
        await _netdDbus!.watchLink(iface, onChange: () {
          unawaited(_tickWantedFromDbus());
        });
      } catch (e) {
        debugPrint('ethernet: wanted D-Bus watch: $e');
      }
    }());
    _wantedTimeout = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickWantedTimeout());
    });
  }

  Future<void> _tickWantedFromDbus() async {
    try {
      if (await _isAdminUp()) {
        _stopWantedWatch();
        _emitAdmin(EthAdminState.on);
        await _startStatusWatch();
        await _refreshStatus();
        return;
      }
      if (_admin == EthAdminState.starting) {
        _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      }
    } catch (e) {
      debugPrint('ethernet: wanted dbus tick: $e');
    }
  }

  Future<void> _tickWantedTimeout() async {
    _wantedTicks++;
    if (_wantedTicks >= _wantedWatchMaxTicks) {
      _stopWantedWatch();
      await setInterfaceEnabled(true);
    }
  }

  Future<void> _refreshStatus() async {
    final details = await linkDetails();
    _emitLink(details);
  }

  @override
  Future<void> setInterfaceEnabled(bool enabled) async {
    _stopWantedWatch();
    if (enabled) {
      _emitAdmin(EthAdminState.starting);
      _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      if (!Directory('/sys/class/net/$iface').existsSync()) {
        final msg =
            '$iface missing (expected RJ45 netdev; PHY/gmac may not have probed)';
        debugPrint('ethernet: $msg');
        _emitAdmin(EthAdminState.error);
        _emitLink(EthLinkState(phase: EthLinkPhase.error, message: msg));
        return;
      }
      try {
        await NetworkdIpv4Apply().setLink(iface: iface, up: true);
      } catch (e) {
        final msg = 'eth link up failed: $e';
        debugPrint('ethernet: $msg');
        _emitAdmin(EthAdminState.error);
        _emitLink(EthLinkState(phase: EthLinkPhase.error, message: msg));
        return;
      }
      _emitAdmin(EthAdminState.on);
      await _startStatusWatch();
      final cfg = await getIpv4Config();
      final apply = await _applyIpv4(cfg);
      if (!apply.ok) {
        debugPrint('ethernet: ${apply.message}');
        _emitLink(
          EthLinkState(
            phase: EthLinkPhase.error,
            message: apply.message,
          ),
        );
      } else {
        await _writeWanted(true);
        await _waitForIpv4(timeout: const Duration(seconds: 50));
      }
      await _refreshStatus();
    } else {
      await _stopStatusWatch();
      try {
        await NetworkdIpv4Apply().setLink(iface: iface, up: false);
      } catch (_) {}
      await _writeWanted(false);
      _emitAdmin(EthAdminState.off);
      _emitLink(EthLinkState.down);
    }
  }

  Future<void> _writeWanted(bool wanted) async {
    try {
      final f = File(ethWantedPath);
      if (wanted) {
        await f.parent.create(recursive: true);
        await f.writeAsString('', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('ethernet: wanted marker failed: $e');
    }
  }

  Future<({bool ok, String? message})> _applyIpv4(EthIpv4Config cfg) async {
    final apply = NetworkdIpv4Apply();
    try {
      if (cfg.mode == EthIpv4Mode.dhcp) {
        await apply.apply(
          iface: iface,
          mode: 'dhcp',
          routeMetric: _metric,
          prefPath: ipv4Path,
        );
      } else {
        await apply.apply(
          iface: iface,
          mode: 'static',
          routeMetric: _metric,
          address: cfg.address,
          prefix: '${cfg.prefixLength}',
          gateway: cfg.gateway.isNotEmpty ? cfg.gateway : null,
          dns: cfg.dns.isNotEmpty ? cfg.dns : null,
          prefPath: ipv4Path,
        );
      }
      return (ok: true, message: null);
    } catch (e) {
      return (ok: false, message: '$e');
    }
  }

  Future<void> _waitForIpv4({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final link = await linkDetails();
      if (link.ipv4 != null && link.ipv4!.isNotEmpty) {
        _emitLink(link);
        return;
      }
      if (link.phase == EthLinkPhase.error) {
        _emitLink(link);
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _emitLink(
      EthLinkState(
        phase: EthLinkPhase.error,
        message: 'no IPv4 after DHCP/static on $iface',
        mac: await _readMac(),
      ),
    );
  }

  Future<bool> _isAdminUp() async {
    try {
      await _ensureDbus();
      final snap = await _netdDbus!.readLink(iface);
      // networkd knows the link; "off" means administratively down.
      return snap.operational.isNotEmpty && snap.operational != 'off';
    } catch (_) {
      try {
        final flags = await File('/sys/class/net/$iface/flags').readAsString();
        final v = int.tryParse(flags.trim()) ?? 0;
        return (v & 0x1) != 0;
      } catch (_) {
        return false;
      }
    }
  }

  Future<String?> _readMac() async {
    try {
      return (await File('/sys/class/net/$iface/address').readAsString())
          .trim();
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readSpeedMbps() async {
    try {
      final s = await File('/sys/class/net/$iface/speed').readAsString();
      return int.tryParse(s.trim());
    } catch (_) {
      return null;
    }
  }

  Future<({String? gw, String? dns})> _readGwDns() async {
    String? gw;
    try {
      final gwR = await _run(
        ['ip', '-4', 'route', 'show', 'default', 'dev', iface],
        log: false,
      );
      gw = WifiLinkParse.defaultGateway(gwR.stdout as String? ?? '');
    } catch (_) {}
    // DNS only from networkd link snapshot — never global resolv.conf.
    return (gw: gw, dns: null);
  }

  @override
  Future<EthLinkState> linkDetails() async {
    if (!Directory('/sys/class/net/$iface').existsSync()) {
      return EthLinkState(
        phase: EthLinkPhase.error,
        message: '$iface missing',
      );
    }
    try {
      await _ensureDbus();
      final snap = await _netdDbus!.readLink(iface);
      if (snap.operational == 'off' || snap.operational.isEmpty) {
        return EthLinkState.down;
      }
      if (snap.operational == 'no-carrier') {
        return EthLinkState(
          phase: EthLinkPhase.noCarrier,
          mac: await _readMac(),
        );
      }
      final hasIp = snap.primaryIpv4 != null && snap.primaryIpv4!.isNotEmpty;
      final gd = await _readGwDns();
      return EthLinkState(
        phase: hasIp ? EthLinkPhase.up : EthLinkPhase.configuring,
        ipv4: snap.primaryIpv4,
        prefixLength: snap.primaryPrefix,
        gateway: snap.gateway ?? gd.gw,
        dns: snap.dns ?? gd.dns,
        mac: await _readMac(),
        speedMbps: await _readSpeedMbps(),
      );
    } catch (e) {
      return EthLinkState(
        phase: EthLinkPhase.error,
        message:
            'networkd D-Bus required (D11): $e — rebuild systemd with NETWORKD',
        mac: await _readMac(),
      );
    }
  }

  @override
  Future<EthIpv4Config> getIpv4Config() async {
    try {
      final f = File(ipv4Path);
      if (!await f.exists()) {
        return EthIpv4Config.dhcpDefault;
      }
      return EthIpv4Store.parse(await f.readAsString());
    } catch (_) {
      return EthIpv4Config.dhcpDefault;
    }
  }

  @override
  Future<void> setIpv4Config(EthIpv4Config config) async {
    final f = File(ipv4Path);
    await f.parent.create(recursive: true);
    await f.writeAsString(EthIpv4Store.serialize(config), flush: true);
    if (_admin == EthAdminState.on) {
      _emitLink(const EthLinkState(phase: EthLinkPhase.configuring));
      final apply = await _applyIpv4(config);
      if (!apply.ok) {
        debugPrint('ethernet: ${apply.message}');
        _emitLink(
          EthLinkState(
            phase: EthLinkPhase.error,
            message: apply.message,
          ),
        );
      } else {
        await _writeWanted(true);
      }
      await _refreshStatus();
    }
  }

  @override
  Future<void> syncFromSystem() async {
    try {
      final wanted = await File(ethWantedPath).exists();
      final adminUp = await _isAdminUp();
      if (adminUp) {
        _stopWantedWatch();
        _emitAdmin(EthAdminState.on);
        await _startStatusWatch();
        await _refreshStatus();
        return;
      }
      if (wanted) {
        // HAL-owned restore: bring link + L3 up (no overlay restore-settings).
        await setInterfaceEnabled(true);
      }
    } catch (e) {
      debugPrint('ethernet: syncFromSystem failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _stopWantedWatch();
    await _stopStatusWatch();
    await _netdDbus?.close();
    try {
      await _bus?.close();
    } catch (_) {}
    _bus = null;
    _netdDbus = null;
    await _adminCtrl.close();
    await _linkCtrl.close();
  }
}

/// Compatibility alias for Demo / older call sites.
typedef LinuxEthernetController = LinuxEthernetSession;
