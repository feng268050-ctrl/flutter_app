import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/wifi_controller.dart';
import 'package:cyber_hal/src/network/wifi_leave_policy.dart';
import 'package:cyber_hal/src/network/wifi_link_parse.dart';
import 'package:cyber_hal/src/network/wifi_models.dart';
import 'package:cyber_hal/src/network/wifi_radio.dart';
import 'package:cyber_hal/src/network/wpa_cli_parse.dart';
import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Linux Wi-Fi session: Streams + wpa D-Bus L2 + networkd L3.
///
/// Prefer constructing via [BoardBindings.wifiSession].
/// Product path uses [WpaSupplicantDbus] only — no runtime `wpa_cli`.
class LinuxWifiSession implements WifiController {
  LinuxWifiSession({
    this.profile,
    String? iface,
    WifiRadio? wifiRadio,
    String? ipv4Path,
    String? wifiWantedPath,
    Map<String, int>? routeMetrics,
    this.prefRoot = '/var/lib/wpa_supplicant',
  })  : iface = iface ??
            profile?.ifaceFor(NetRole.wifiStation) ??
            'wlan0',
        wifiRadio = wifiRadio ?? SystemdWifiRadio(),
        _routeMetrics = routeMetrics ?? profile?.routeMetrics ?? const {},
        ipv4Path = ipv4Path ??
            WlanIpv4Store.pathFor(
              iface ?? profile?.ifaceFor(NetRole.wifiStation) ?? 'wlan0',
              prefRoot: prefRoot,
            ),
        wifiWantedPath = wifiWantedPath ??
            '$prefRoot/wifi-wanted';

  final BoardProfile? profile;
  final String iface;
  final WifiRadio wifiRadio;
  final String ipv4Path;
  final String wifiWantedPath;
  final String prefRoot;
  final Map<String, int> _routeMetrics;

  final _radioCtrl = StreamController<WifiRadioState>.broadcast();
  final _connCtrl = StreamController<WifiConnectionState>.broadcast();

  WifiRadioState _radio = WifiRadioState.off;
  WifiConnectionState _conn = WifiConnectionState.disconnected;
  Timer? _wantedTimeout;
  int _wantedTicks = 0;

  /// Last BSSID we applied L3 for — re-DHCP when roaming to another AP.
  String? _ipv4AppliedBssid;
  bool _ipv4ApplyInFlight = false;

  DBusClient? _bus;
  WpaSupplicantDbus? _wpaDbus;
  NetworkdDbus? _netdDbus;

  static const _wantedWatchMaxTicks = 120;

  int get _metric =>
      _routeMetrics[iface] ??
      profile?.routeMetricFor(iface) ??
      NetworkdIpv4Apply.defaultRouteMetric(iface);

  @override
  WifiRadioState get currentRadio => _radio;

  @override
  WifiConnectionState get currentConnection => _conn;

  @override
  String get interfaceName => iface;

  @override
  Stream<WifiRadioState> get radio => _radioCtrl.stream;

  @override
  Stream<WifiConnectionState> get connection => _connCtrl.stream;

  void _emitRadio(WifiRadioState s) {
    _radio = s;
    if (!_radioCtrl.isClosed) {
      _radioCtrl.add(s);
    }
  }

  void _emitConn(WifiConnectionState s) {
    _conn = s;
    if (!_connCtrl.isClosed) {
      _connCtrl.add(s);
    }
  }

  Future<void> _ensureDbus() async {
    if (_bus != null) {
      return;
    }
    _bus = DBusClient.system();
    _wpaDbus = WpaSupplicantDbus(client: _bus);
    _netdDbus = NetworkdDbus(client: _bus);
  }

  Future<ProcessResult> _run(List<String> cmd, {bool log = true}) async {
    if (cmd.isEmpty) {
      return ProcessResult(0, 1, '', 'empty command');
    }
    if (log) {
      lwsTrace('wifi: ${cmd.join(' ')}');
    }
    return Process.run(cmd.first, cmd.sublist(1));
  }

  Future<bool> _wpaLive() async {
    try {
      await _ensureDbus();
      final snap = await _wpaDbus!.readIface(iface);
      final wpaState = snap.wpaStateToken;
      return wpaState.isNotEmpty && wpaState != 'INTERFACE_DISABLED';
    } catch (_) {
      return false;
    }
  }

  void _stopWantedWatch() {
    _wantedTimeout?.cancel();
    _wantedTimeout = null;
    _wantedTicks = 0;
  }

  /// Pref says radio should be on — wait for wpa D-Bus Interface (not Timer status).
  void _startWantedWatch() {
    _stopWantedWatch();
    unawaited(() async {
      try {
        await _ensureDbus();
        await _wpaDbus!.watchInterface(iface, onChange: () {
          unawaited(_tickWantedFromDbus());
        });
      } catch (e) {
        debugPrint('wifi: wanted D-Bus watch: $e');
      }
    }());
    _wantedTimeout = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickWantedTimeout());
    });
  }

  Future<void> _tickWantedFromDbus() async {
    try {
      if (await _wpaLive()) {
        _stopWantedWatch();
        _emitRadio(WifiRadioState.on);
        await _startStatusWatch();
        await _refreshStatus();
      } else if (_radio == WifiRadioState.starting) {
        _emitConn(
          const WifiConnectionState(
            phase: WifiConnectionPhase.associating,
            message: 'Starting…',
          ),
        );
      }
    } catch (e) {
      debugPrint('wifi: wanted dbus tick: $e');
    }
  }

  Future<void> _tickWantedTimeout() async {
    _wantedTicks++;
    if (_wantedTicks >= _wantedWatchMaxTicks) {
      _stopWantedWatch();
      await setRadioEnabled(true);
    }
  }

  Future<void> _startStatusWatch() async {
    await _ensureDbus();
    await _wpaDbus!.watchInterface(iface, onChange: () {
      unawaited(_refreshStatus());
    });
    await _netdDbus!.watchLink(iface, onChange: () {
      unawaited(_refreshStatus());
    });
  }

  Future<void> _stopStatusWatch() async {
    await _wpaDbus?.cancelWatch();
    await _netdDbus?.cancelWatch();
  }

  @override
  Future<void> setRadioEnabled(bool enabled) async {
    _stopWantedWatch();
    if (enabled) {
      _emitRadio(WifiRadioState.starting);
      try {
        await wifiRadio.setEnabled(true);
      } catch (e) {
        final msg = 'wifi-stack-up failed: $e';
        debugPrint('wifi: $msg');
        _emitRadio(WifiRadioState.error);
        _emitConn(
          WifiConnectionState(
            phase: WifiConnectionPhase.failed,
            message: msg,
          ),
        );
        return;
      }
      _emitRadio(WifiRadioState.on);
      await _writeWanted(true);
      await _startStatusWatch();
      await _refreshStatus();
      // Saved network may auto-associate; force a fresh DHCP lease (new gateway).
      await _ensureIpv4ForCurrentAssoc(force: true);
    } else {
      await _stopStatusWatch();
      try {
        await wifiRadio.setEnabled(false);
      } catch (_) {}
      await _writeWanted(false);
      _ipv4AppliedBssid = null;
      _emitRadio(WifiRadioState.off);
      _emitConn(WifiConnectionState.disconnected);
    }
  }

  Future<void> _writeWanted(bool wanted) async {
    try {
      final f = File(wifiWantedPath);
      if (wanted) {
        await f.parent.create(recursive: true);
        await f.writeAsString('', flush: true);
      } else if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      debugPrint('wifi: wanted marker failed: $e');
    }
  }

  Future<void> _refreshStatus() async {
    if (_radio != WifiRadioState.on) {
      return;
    }
    try {
      final link = await linkDetails();
      _emitConn(link);
      if (link.phase == WifiConnectionPhase.connected ||
          link.phase == WifiConnectionPhase.obtainingIp) {
        unawaited(_ensureIpv4ForCurrentAssoc());
      } else if (link.phase == WifiConnectionPhase.disconnected) {
        _ipv4AppliedBssid = null;
      }
    } catch (e) {
      lwsTrace('wifi: status D-Bus refresh failed: $e');
    }
  }

  /// Re-apply L3 when associating to a new BSS (same SSID ≠ same gateway).
  Future<void> _ensureIpv4ForCurrentAssoc({bool force = false}) async {
    if (_radio != WifiRadioState.on || _ipv4ApplyInFlight) {
      return;
    }
    await _ensureDbus();
    final snap = await _wpaDbus!.readIface(iface);
    if (snap.wpaStateToken != 'COMPLETED') {
      return;
    }
    final bssid = (snap.bssid ?? '').toLowerCase();
    if (!force &&
        bssid.isNotEmpty &&
        bssid == (_ipv4AppliedBssid ?? '').toLowerCase()) {
      return;
    }
    _ipv4ApplyInFlight = true;
    try {
      final cfg = await getIpv4Config();
      final apply = await _applyIpv4(cfg);
      if (!apply.ok) {
        debugPrint('wifi: re-apply IPv4 failed: ${apply.message}');
        return;
      }
      _ipv4AppliedBssid = bssid.isNotEmpty ? bssid : null;
      await _waitForIpv4(
        ssid: snap.ssid ?? _conn.ssid ?? '',
        timeout: const Duration(seconds: 30),
      );
    } finally {
      _ipv4ApplyInFlight = false;
    }
  }

  @override
  Future<WifiConnectionState> linkDetails() async {
    await _ensureDbus();
    final snap = await _wpaDbus!.readIface(iface);
    var phase = WpaCliParse.phaseFromStatus({
      'wpa_state': snap.wpaStateToken,
    });
    String? ipv4;
    int? prefix;
    String? gateway;
    String? dns;
    try {
      final link = await _netdDbus!.readLink(iface);
      ipv4 = link.primaryIpv4;
      prefix = link.primaryPrefix;
      gateway = link.gateway;
      dns = link.dns;
    } catch (e) {
      // D11: L3 status is networkd D-Bus only — do not invent addresses via `ip`.
      lwsTrace('wifi: networkd L3 D-Bus unavailable: $e');
      if (phase == WifiConnectionPhase.connected) {
        phase = WifiConnectionPhase.obtainingIp;
      }
    }
    if (phase == WifiConnectionPhase.connected &&
        (ipv4 == null || ipv4.isEmpty)) {
      phase = WifiConnectionPhase.obtainingIp;
    }
    return WifiConnectionState(
      phase: phase,
      ssid: snap.ssid,
      bssid: snap.bssid,
      ipv4: ipv4,
      prefixLength: prefix,
      gateway: gateway ?? await _readGateway(),
      // DNS only from networkd link — never global resolv.conf or dead pref paths.
      dns: dns,
      frequencyMhz: snap.frequencyMhz,
      signalDbm: snap.signalDbm,
    );
  }

  Future<String?> _readGateway() async {
    try {
      final r = await _run(
        ['ip', '-4', 'route', 'show', 'default', 'dev', iface],
        log: false,
      );
      return WifiLinkParse.defaultGateway(r.stdout as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<WifiAccessPoint>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_radio != WifiRadioState.on) {
      return const [];
    }
    await _ensureDbus();
    final wpa = _wpaDbus!;
    try {
      await wpa.scan(iface);
    } catch (e) {
      debugPrint('wifi: dbus scan failed: $e');
      return const [];
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final rows = await wpa.listScanResults(iface);
        if (rows.isNotEmpty) {
          return rows
              .map(
                (r) => WifiAccessPoint(
                  ssid: r.ssid,
                  signalDbm: r.signalDbm,
                  flags: r.requiresPsk ? '[WPA2-PSK-CCMP]' : '[ESS]',
                  bssid: r.bssid,
                ),
              )
              .toList();
        }
      } catch (_) {}
    }
    try {
      final rows = await wpa.listScanResults(iface);
      return rows
          .map(
            (r) => WifiAccessPoint(
              ssid: r.ssid,
              signalDbm: r.signalDbm,
              flags: r.requiresPsk ? '[WPA2-PSK-CCMP]' : '[ESS]',
              bssid: r.bssid,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> connect({
    required String ssid,
    String? psk,
    String? bssid,
    bool hidden = false,
    bool requiresPsk = false,
  }) async {
    if (_radio != WifiRadioState.on) {
      await setRadioEnabled(true);
      if (_radio != WifiRadioState.on) {
        return;
      }
    }
    // Ensure iface is up after a prior disconnect (must not leave link down).
    try {
      await NetworkdIpv4Apply().setLink(iface: iface, up: true);
    } catch (_) {}
    _ipv4AppliedBssid = null;
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.associating,
        ssid: ssid,
        bssid: bssid,
      ),
    );
    await _ensureDbus();
    try {
      // Appliance single-network policy: connectNetwork replaces selection.
      await _wpaDbus!.connectNetwork(
        iface,
        ssid: ssid,
        psk: psk,
        bssid: bssid,
        hidden: hidden,
        requiresPsk: requiresPsk,
      );
    } catch (e) {
      _emitConn(
        WifiConnectionState(
          phase: WifiConnectionPhase.failed,
          ssid: ssid,
          message: 'wpa connect failed: $e',
        ),
      );
      return;
    }

    // Hidden SSIDs need active Probe Request rounds — allow longer assoc.
    final deadline = DateTime.now().add(
      hidden ? const Duration(seconds: 40) : const Duration(seconds: 25),
    );
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final snap = await _wpaDbus!.readIface(iface);
      if (snap.wpaStateToken == 'COMPLETED') {
        _emitConn(
          WifiConnectionState(
            phase: WifiConnectionPhase.obtainingIp,
            ssid: ssid,
            bssid: snap.bssid ?? bssid,
          ),
        );
        final ipCfg = await getIpv4Config();
        final apply = await _applyIpv4(ipCfg);
        if (!apply.ok) {
          final msg = apply.message ?? 'DHCP/static IP failed';
          debugPrint('wifi: $msg');
          _emitConn(
            WifiConnectionState(
              phase: WifiConnectionPhase.failed,
              ssid: ssid,
              message: msg,
            ),
          );
          return;
        }
        _ipv4AppliedBssid = (snap.bssid ?? bssid)?.toLowerCase();
        await _waitForIpv4(
          ssid: ssid,
          timeout: const Duration(seconds: 50),
        );
        return;
      }
    }
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.failed,
        ssid: ssid,
        message: 'association timeout',
      ),
    );
  }

  Future<({bool ok, String? message})> _applyIpv4(WlanIpv4Config cfg) async {
    final apply = NetworkdIpv4Apply();
    try {
      if (cfg.mode == WlanIpv4Mode.dhcp) {
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
    required String ssid,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final link = await linkDetails();
      if (link.ipv4 != null && link.ipv4!.isNotEmpty) {
        _emitConn(link.copyWith(phase: WifiConnectionPhase.connected));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.failed,
        ssid: ssid,
        message: 'no IPv4 after DHCP/static on $iface',
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    assert(WifiLeavePolicy.keepsLinkUp(WifiLeaveKind.disconnect));
    assert(!WifiLeavePolicy.removesSavedNetworks(WifiLeaveKind.disconnect));
    await _ensureDbus();
    try {
      await _wpaDbus!.disconnect(iface);
    } catch (e) {
      debugPrint('wifi: dbus disconnect: $e');
    }
    // Stop auto-reassoc without wiping saved networks (≠ forget).
    if (WifiLeavePolicy.disablesCurrentNetwork(WifiLeaveKind.disconnect)) {
      try {
        await _wpaDbus!.disableCurrentNetwork(iface);
      } catch (_) {}
    }
    _ipv4AppliedBssid = null;
    try {
      await NetworkdIpv4Apply().setLink(iface: iface, up: true);
      await Process.run('networkctl', ['reconfigure', iface]);
    } catch (_) {}
    _emitConn(WifiConnectionState.disconnected);
  }

  @override
  Future<void> forget(String ssid) async {
    assert(WifiLeavePolicy.removesSavedNetworks(WifiLeaveKind.forget));
    await _ensureDbus();
    final wasCurrent = _conn.ssid == ssid;
    if (wasCurrent) {
      try {
        await _wpaDbus!.disconnect(iface);
      } catch (_) {}
    }
    try {
      await _wpaDbus!.removeNetworksBySsid(iface, ssid);
      await _wpaDbus!.saveConfig(iface);
    } catch (e) {
      debugPrint('wifi: forget dbus: $e');
      rethrow;
    }
    _ipv4AppliedBssid = null;
    if (wasCurrent) {
      _emitConn(WifiConnectionState.disconnected);
    }
  }

  @override
  Future<List<WifiSavedNetwork>> savedNetworks() async {
    await _ensureDbus();
    final nets = await _wpaDbus!.listNetworks(iface);
    return nets
        .map((n) => WifiSavedNetwork(networkId: n.networkId, ssid: n.ssid))
        .toList();
  }

  @override
  Future<WlanIpv4Config> getIpv4Config() async {
    try {
      final f = File(ipv4Path);
      if (!await f.exists()) {
        return WlanIpv4Config.dhcpDefault;
      }
      return WlanIpv4Store.parse(await f.readAsString());
    } catch (_) {
      return WlanIpv4Config.dhcpDefault;
    }
  }

  @override
  Future<void> setIpv4Config(WlanIpv4Config config) async {
    final f = File(ipv4Path);
    await f.parent.create(recursive: true);
    await f.writeAsString(WlanIpv4Store.serialize(config), flush: true);
    // Apply while associated (including DHCP in flight) so prefs take effect
    // before phase flips to connected.
    if (_radio == WifiRadioState.on &&
        (_conn.phase == WifiConnectionPhase.connected ||
            _conn.phase == WifiConnectionPhase.obtainingIp)) {
      final apply = await _applyIpv4(config);
      if (!apply.ok) {
        debugPrint('wifi: ${apply.message}');
      }
      await _refreshStatus();
    }
  }

  @override
  Future<void> syncFromSystem() async {
    try {
      final wanted = await File(wifiWantedPath).exists();
      if (await _wpaLive()) {
        _stopWantedWatch();
        _emitRadio(WifiRadioState.on);
        await _startStatusWatch();
        await _refreshStatus();
        return;
      }
      if (wanted) {
        // HAL-owned restore: bring radio up (no overlay restore-settings).
        await setRadioEnabled(true);
      }
    } catch (e) {
      debugPrint('wifi: syncFromSystem failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _stopWantedWatch();
    await _stopStatusWatch();
    await _wpaDbus?.close();
    await _netdDbus?.close();
    try {
      await _bus?.close();
    } catch (_) {}
    _bus = null;
    _wpaDbus = null;
    _netdDbus = null;
    await _radioCtrl.close();
    await _connCtrl.close();
  }
}

/// Compatibility alias for Demo / older call sites.
typedef LinuxWpaWifiController = LinuxWifiSession;
