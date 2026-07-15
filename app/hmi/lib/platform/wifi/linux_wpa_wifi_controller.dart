import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/lws_trace.dart';
import 'package:lws_hmi/platform/wifi/wifi_controller.dart';
import 'package:lws_hmi/platform/wifi/wifi_link_parse.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';
import 'package:lws_hmi/platform/wifi/wpa_cli_parse.dart';

/// Linux Wi-Fi via on-demand helpers + `wpa_cli`.
class LinuxWpaWifiController implements WifiController {
  final String iface;
  final List<String> stackUp;
  final List<String> stackDown;
  final List<String> dhcpHelper;
  final List<String> staticHelper;
  final String ipv4Path;
  final String wpaCliBin;
  final String wifiWantedPath;

  LinuxWpaWifiController({
    this.iface = 'wlan0',
    this.stackUp = const ['/usr/lib/lws-hmi/wifi-stack-up.sh'],
    this.stackDown = const ['/usr/lib/lws-hmi/wifi-stack-down.sh'],
    this.dhcpHelper = const ['/usr/lib/lws-hmi/wlan0-dhcp.sh'],
    this.staticHelper = const ['/usr/lib/lws-hmi/wlan0-static.sh'],
    this.ipv4Path = WlanIpv4Store.defaultPath,
    this.wpaCliBin = 'wpa_cli',
    this.wifiWantedPath = '/var/lib/lws-hmi/wifi-wanted',
  });

  final _radioCtrl = StreamController<WifiRadioState>.broadcast();
  final _connCtrl = StreamController<WifiConnectionState>.broadcast();

  WifiRadioState _radio = WifiRadioState.off;
  WifiConnectionState _conn = WifiConnectionState.disconnected;
  Timer? _poll;
  Timer? _wantedWatch;
  int _wantedTicks = 0;

  static const _wantedWatchMaxTicks = 120;

  @override
  WifiRadioState get currentRadio => _radio;

  @override
  WifiConnectionState get currentConnection => _conn;

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

  Future<ProcessResult> _run(List<String> cmd, {bool log = true}) async {
    if (cmd.isEmpty) {
      return ProcessResult(0, 1, '', 'empty command');
    }
    if (log) {
      lwsTrace('wifi: ${cmd.join(' ')}');
    }
    return Process.run(cmd.first, cmd.sublist(1));
  }

  String _processFailMessage(ProcessResult r, String fallback) {
    final err = (r.stderr as String? ?? '').trim();
    final out = (r.stdout as String? ?? '').trim();
    if (err.isNotEmpty) {
      return err;
    }
    if (out.isNotEmpty) {
      return out;
    }
    return '$fallback (exit ${r.exitCode})';
  }

  Future<String> _wpa(List<String> args, {bool log = true}) async {
    final r = await _run([wpaCliBin, '-i', iface, ...args], log: log);
    return (r.stdout as String? ?? '').trim();
  }

  Future<bool> _wpaLive() async {
    try {
      final raw = await _wpa(const ['status'], log: false);
      final st = WpaCliParse.status(raw);
      final wpaState = (st['wpa_state'] ?? '').toUpperCase();
      return wpaState.isNotEmpty && wpaState != 'INTERFACE_DISABLED';
    } catch (_) {
      return false;
    }
  }

  void _stopWantedWatch() {
    _wantedWatch?.cancel();
    _wantedWatch = null;
    _wantedTicks = 0;
  }

  /// Pref says radio should be on (boot restore after HMI) — mirror manual
  /// enable: show [starting] / associating and poll until the stack is live.
  /// Do not call [setRadioEnabled] immediately (restore owns bring-up).
  void _startWantedWatch() {
    _stopWantedWatch();
    _wantedWatch = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickWantedWatch());
    });
  }

  Future<void> _tickWantedWatch() async {
    _wantedTicks++;
    try {
      if (await _wpaLive()) {
        _stopWantedWatch();
        _emitRadio(WifiRadioState.on);
        _startPoll();
        await _refreshStatus();
        return;
      }
      if (_radio == WifiRadioState.starting) {
        _emitConn(
          const WifiConnectionState(
            phase: WifiConnectionPhase.associating,
            message: 'Starting…',
          ),
        );
      }
      if (_wantedTicks >= _wantedWatchMaxTicks) {
        _stopWantedWatch();
        // Restore may have failed — same path as a manual toggle.
        await setRadioEnabled(true);
      }
    } catch (e) {
      debugPrint('wifi: wanted watch: $e');
    }
  }

  @override
  Future<void> setRadioEnabled(bool enabled) async {
    _stopWantedWatch();
    if (enabled) {
      _emitRadio(WifiRadioState.starting);
      final r = await _run(stackUp);
      if (r.exitCode != 0) {
        final msg = _processFailMessage(r, 'wifi-stack-up failed');
        // Always surface bring-up failures (operators do not enable LWS_HMI_TRACE).
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
      _startPoll();
      await _refreshStatus();
    } else {
      _poll?.cancel();
      _poll = null;
      await _run(stackDown);
      await _writeWanted(false);
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

  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshStatus());
    });
  }

  Future<void> _refreshStatus() async {
    if (_radio != WifiRadioState.on) {
      return;
    }
    try {
      _emitConn(await linkDetails());
    } catch (e) {
      lwsTrace('wifi: status poll failed: $e');
    }
  }

  @override
  Future<WifiConnectionState> linkDetails() async {
    final raw = await _wpa(const ['status'], log: false);
    final st = WpaCliParse.status(raw);
    var phase = WpaCliParse.phaseFromStatus(st);
    final inet = await _readInet4();
    final ipv4 = inet.address;
    if (phase == WifiConnectionPhase.connected &&
        (ipv4 == null || ipv4.isEmpty)) {
      phase = WifiConnectionPhase.obtainingIp;
    }
    return WifiConnectionState(
      phase: phase,
      ssid: st['ssid'],
      bssid: st['bssid'],
      ipv4: ipv4,
      prefixLength: inet.prefix,
      gateway: await _readGateway(),
      dns: await _readDns(),
      frequencyMhz: int.tryParse(st['freq'] ?? ''),
      signalDbm: int.tryParse(st['rssi'] ?? st['signal'] ?? ''),
    );
  }

  Future<({String? address, int? prefix})> _readInet4() async {
    try {
      final r = await _run(
        ['ip', '-4', '-o', 'addr', 'show', 'dev', iface],
        log: false,
      );
      return WifiLinkParse.inet4(r.stdout as String? ?? '');
    } catch (_) {
      return (address: null, prefix: null);
    }
  }

  Future<String?> _readGateway() async {
    try {
      final r = await _run(
        ['ip', '-4', 'route', 'show', 'default'],
        log: false,
      );
      return WifiLinkParse.defaultGateway(r.stdout as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readDns() async {
    try {
      final prefs = File('/var/lib/lws-hmi/wlan0-resolv.conf');
      if (await prefs.exists()) {
        final dns = WifiLinkParse.primaryDns(await prefs.readAsString());
        if (dns != null) {
          return dns;
        }
      }
      final r = File('/etc/resolv.conf');
      if (await r.exists()) {
        return WifiLinkParse.primaryDns(await r.readAsString());
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<WifiAccessPoint>> scan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_radio != WifiRadioState.on) {
      return const [];
    }
    await _wpa(const ['scan']);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final raw = await _wpa(const ['scan_results'], log: false);
      final aps = WpaCliParse.scanResults(raw);
      if (aps.isNotEmpty) {
        return aps;
      }
    }
    final raw = await _wpa(const ['scan_results'], log: false);
    return WpaCliParse.scanResults(raw);
  }

  @override
  Future<void> connect({
    required String ssid,
    String? psk,
    bool hidden = false,
    bool save = true,
  }) async {
    if (_radio != WifiRadioState.on) {
      await setRadioEnabled(true);
      if (_radio != WifiRadioState.on) {
        return;
      }
    }
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.associating,
        ssid: ssid,
      ),
    );
    final add = await _wpa(const ['add_network']);
    final id = int.tryParse(add.trim());
    if (id == null) {
      _emitConn(
        const WifiConnectionState(
          phase: WifiConnectionPhase.failed,
          message: 'add_network failed',
        ),
      );
      return;
    }
    await _wpa(['set_network', '$id', 'ssid', WpaCliParse.quoteWpaString(ssid)]);
    if (WpaCliParse.needsScanSsid(hidden: hidden)) {
      await _wpa(['set_network', '$id', 'scan_ssid', '1']);
    }
    if (psk == null || psk.isEmpty) {
      await _wpa(['set_network', '$id', 'key_mgmt', 'NONE']);
    } else {
      // Do not log PSK.
      await _run(
        [wpaCliBin, '-i', iface, 'set_network', '$id', 'psk', WpaCliParse.quoteWpaString(psk)],
        log: false,
      );
    }
    await _wpa(['enable_network', '$id']);
    await _wpa(['select_network', '$id']);
    if (save) {
      await _wpa(const ['save_config']);
    }

    // Wait for COMPLETED then apply IP mode.
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final st = WpaCliParse.status(await _wpa(const ['status'], log: false));
      if (WpaCliParse.phaseFromStatus(st) == WifiConnectionPhase.connected) {
        _emitConn(
          WifiConnectionState(
            phase: WifiConnectionPhase.obtainingIp,
            ssid: ssid,
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
    if (cfg.mode == WlanIpv4Mode.dhcp) {
      final r = await _run([...dhcpHelper, 'start']);
      if (r.exitCode != 0) {
        return (
          ok: false,
          message: _processFailMessage(r, 'wlan0-dhcp failed'),
        );
      }
      return (ok: true, message: null);
    }
    final r = await _run([
      ...staticHelper,
      cfg.address,
      '${cfg.prefixLength}',
      if (cfg.gateway.isNotEmpty) cfg.gateway else '',
      if (cfg.dns.isNotEmpty) cfg.dns else '',
    ]);
    if (r.exitCode != 0) {
      return (
        ok: false,
        message: _processFailMessage(r, 'wlan0-static failed'),
      );
    }
    return (ok: true, message: null);
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
    await _wpa(const ['disconnect']);
    await _run([...dhcpHelper, 'stop']);
    _emitConn(WifiConnectionState.disconnected);
  }

  @override
  Future<void> forget(String ssid) async {
    final saved = await savedNetworks();
    for (final n in saved.where((n) => n.ssid == ssid)) {
      await _wpa(['remove_network', '${n.networkId}']);
    }
    await _wpa(const ['save_config']);
    if (_conn.ssid == ssid) {
      _emitConn(WifiConnectionState.disconnected);
    }
  }

  @override
  Future<List<WifiSavedNetwork>> savedNetworks() async {
    final raw = await _wpa(const ['list_networks'], log: false);
    return WpaCliParse.listNetworks(raw);
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
    if (_radio == WifiRadioState.on &&
        _conn.phase == WifiConnectionPhase.connected) {
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
        _startPoll();
        await _refreshStatus();
        return;
      }
      if (wanted) {
        // Boot restore brings the stack up after HMI — UI tracks like manual on.
        _emitRadio(WifiRadioState.starting);
        _emitConn(
          const WifiConnectionState(
            phase: WifiConnectionPhase.associating,
            message: 'Starting…',
          ),
        );
        _startWantedWatch();
      }
    } catch (e) {
      debugPrint('wifi: syncFromSystem failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _stopWantedWatch();
    _poll?.cancel();
    await _radioCtrl.close();
    await _connCtrl.close();
  }
}
