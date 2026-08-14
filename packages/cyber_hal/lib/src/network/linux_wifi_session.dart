import 'dart:async';
import 'dart:io';

import 'package:cyber_hal/src/core/net_role.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:cyber_hal/src/network/primary_network.dart';
import 'package:cyber_hal/src/network/wifi_controller.dart';
import 'package:cyber_hal/src/network/wifi_credential_migration.dart';
import 'package:cyber_hal/src/network/wifi_credential_vault.dart';
import 'package:cyber_hal/src/network/wifi_leave_policy.dart';
import 'package:cyber_hal/src/network/wifi_link_parse.dart';
import 'package:cyber_hal/src/network/wifi_models.dart';
import 'package:cyber_hal/src/network/wifi_radio.dart';
import 'package:cyber_hal/src/network/wpa_cli_parse.dart';
import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart'
    show WpaScanResult, WpaSupplicantDbus, wpaSecurityLabel;
import 'package:cyber_hal/src/profile/board_profile.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// Linux Wi-Fi session: Streams + wpa D-Bus L2 + networkd L3.
///
/// Prefer constructing via [BoardBindings.wifiSession].
/// Product path uses [WpaSupplicantDbus] only — no runtime `wpa_cli`.
///
/// PSK at rest lives in [WifiCredentialVault] (HAL Secrets); conf stays
/// metadata-only via `mem_only_psk=1`.
class LinuxWifiSession implements WifiController {
  LinuxWifiSession({
    this.profile,
    String? iface,
    WifiRadio? wifiRadio,
    String? ipv4Path,
    String? wifiWantedPath,
    Map<String, int>? routeMetrics,
    this.prefRoot = '/var/lib/wpa_supplicant',
    KekProvider? secrets,
    WifiCredentialVault? vault,
    String? wpaConfPath,
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
            '$prefRoot/wifi-wanted',
        wpaConfPath = wpaConfPath ?? '$prefRoot/wpa_supplicant.conf',
        vault = vault ??
            (secrets != null
                ? WifiCredentialVault(
                    secrets: secrets,
                    path: '$prefRoot/credentials.vault',
                  )
                : null);

  final BoardProfile? profile;
  final String iface;
  final WifiRadio wifiRadio;
  final String ipv4Path;
  final String wifiWantedPath;
  final String prefRoot;
  final String wpaConfPath;
  final Map<String, int> _routeMetrics;

  /// Null only in host stubs without Secrets — product path always injects via
  /// [BoardBindings.wifiSession].
  final WifiCredentialVault? vault;

  final _radioCtrl = StreamController<WifiRadioState>.broadcast();
  final _connCtrl = StreamController<WifiConnectionState>.broadcast();

  WifiRadioState _radio = WifiRadioState.off;
  WifiConnectionState _conn = WifiConnectionState.disconnected;
  Timer? _wantedTimeout;
  int _wantedTicks = 0;

  /// Last BSSID we applied L3 for — re-DHCP when roaming to another AP.
  String? _ipv4AppliedBssid;
  bool _ipv4ApplyInFlight = false;

  /// Sticky **true** only after a positive IEEE 802.11 probe.
  ///
  /// Negatives are re-checked: ynh960 modem bring-up often creates `wlan0`
  /// after the first [syncFromSystem] probe — caching `false` forever made
  /// [linkDetails] report hardcoded SSID `virtio` while networkd already had
  /// the real station IPv4.
  bool? _ieee80211;

  DBusClient? _bus;
  WpaSupplicantDbus? _wpaDbus;
  NetworkdDbus? _netdDbus;

  static const _wantedWatchMaxTicks = 120;

  int get _metric => PrimaryNetworkPolicy.effectiveMetric(
        iface: iface,
        role: NetRole.wifiStation,
        profile: profile,
        routeMetrics: _routeMetrics,
      );

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

  Future<void> _ensureDbus({bool needWpa = true}) async {
    if (_bus != null) {
      if (needWpa && _wpaDbus == null) {
        _wpaDbus = WpaSupplicantDbus(client: _bus);
      }
      return;
    }
    _bus = DBusClient.system();
    _netdDbus = NetworkdDbus(client: _bus);
    if (needWpa) {
      _wpaDbus = WpaSupplicantDbus(client: _bus);
    }
  }

  /// One-shot plaintext conf → vault, then inject Auto Join secrets into wpa.
  ///
  /// Safe to call whenever wpa D-Bus is ready (idempotent migration).
  Future<void> _prepareVaultAndInject() async {
    final v = vault;
    if (v == null || _wpaDbus == null) {
      return;
    }
    try {
      final n = await WpaConfPskMigration.migrateFile(
        confPath: wpaConfPath,
        vault: v,
      );
      if (n > 0) {
        debugPrint('wifi: migrated $n plaintext PSK(s) into credential vault');
      }
    } catch (e) {
      debugPrint('wifi: vault migration failed: $e');
    }
    try {
      await _wpaDbus!.injectVaultSecretsForAutoJoin(
        iface,
        lookupPsk: v.get,
      );
    } catch (e) {
      debugPrint('wifi: vault inject failed: $e');
    }
  }

  Future<bool> _isIeee80211() async {
    if (_ieee80211 == true) {
      return true;
    }
    final v = await wifiIfaceIsIeee80211(iface);
    if (v) {
      _ieee80211 = true;
    }
    return v;
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
        if (!await _isIeee80211()) {
          // Stand-in: radio bring-up is synchronous (no wpa).
          if (await wifiRadio.isEnabled()) {
            _stopWantedWatch();
            _emitRadio(WifiRadioState.on);
            await _startStatusWatch();
            await _refreshStatus();
            await _ensureStandInIpv4(force: true);
          }
          return;
        }
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
        await _prepareVaultAndInject();
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
    final ieee = await _isIeee80211();
    await _ensureDbus(needWpa: ieee);
    if (ieee) {
      await _wpaDbus!.watchInterface(iface, onChange: () {
        unawaited(_refreshStatus());
      });
    }
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
      if (_radio == WifiRadioState.on) {
        // Already up — do not re-run modem bring-up (AIC SDIO unbind/insmod).
        return;
      }
      _emitRadio(WifiRadioState.starting);
      // Persist wanted before stack bring-up so OTA reboot-after-arm still
      // restores Wi‑Fi on the next boot if reboot races the enable path.
      await _writeWanted(true);
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
      await _startStatusWatch();
      if (await _isIeee80211()) {
        await _prepareVaultAndInject();
        // Saved network may auto-associate; force a fresh DHCP lease (new gateway).
        await _ensureIpv4ForCurrentAssoc(force: true);
      } else {
        await _ensureStandInIpv4(force: true);
      }
      await _refreshStatus();
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
        if (await _isIeee80211()) {
          unawaited(_ensureIpv4ForCurrentAssoc());
        } else {
          unawaited(_ensureStandInIpv4());
        }
      } else if (link.phase == WifiConnectionPhase.disconnected) {
        _ipv4AppliedBssid = null;
      }
    } catch (e) {
      lwsTrace('wifi: status D-Bus refresh failed: $e');
    }
  }

  /// Virtio/Ethernet stand-in `wlan0`: DHCP/static via networkd (no wpa).
  Future<void> _ensureStandInIpv4({bool force = false}) async {
    if (_radio != WifiRadioState.on || _ipv4ApplyInFlight) {
      return;
    }
    if (!force && _ipv4AppliedBssid == 'stand-in') {
      return;
    }
    _ipv4ApplyInFlight = true;
    try {
      await _ensureDbus(needWpa: false);
      final cfg = await getIpv4Config();
      final apply = await _applyIpv4(cfg);
      if (!apply.ok) {
        debugPrint('wifi: stand-in IPv4 failed: ${apply.message}');
        return;
      }
      _ipv4AppliedBssid = 'stand-in';
      await _waitForIpv4(
        ssid: 'virtio',
        timeout: const Duration(seconds: 30),
      );
    } finally {
      _ipv4ApplyInFlight = false;
    }
  }

  /// Re-apply L3 when associating to a new BSS (same SSID ≠ same gateway).
  Future<void> _ensureIpv4ForCurrentAssoc({bool force = false}) async {
    if (_radio != WifiRadioState.on || _ipv4ApplyInFlight) {
      return;
    }
    if (!await _isIeee80211()) {
      await _ensureStandInIpv4(force: force);
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
    if (!await _isIeee80211()) {
      await _ensureDbus(needWpa: false);
      try {
        final link = await _netdDbus!.readLink(iface);
        final ipv4 = link.primaryIpv4;
        final mac = await _readMac();
        if (ipv4 != null && ipv4.isNotEmpty) {
          return WifiConnectionState(
            phase: WifiConnectionPhase.connected,
            ssid: 'virtio',
            ipv4: ipv4,
            prefixLength: link.primaryPrefix,
            gateway: link.gateway ?? await _readGateway(),
            dns: link.dns,
            macAddress: mac,
            linkSpeedMbps: await _readLinkSpeedMbps(),
            security: 'open',
          );
        }
        final op = link.operational;
        if (op == 'routable' ||
            op == 'carrier' ||
            op == 'degraded' ||
            op == 'enslaved') {
          return WifiConnectionState(
            phase: WifiConnectionPhase.obtainingIp,
            ssid: 'virtio',
            message: 'DHCP…',
            macAddress: mac,
          );
        }
        return WifiConnectionState(
          phase: WifiConnectionPhase.disconnected,
          ssid: 'virtio',
          macAddress: mac,
        );
      } catch (e) {
        return WifiConnectionState(
          phase: WifiConnectionPhase.failed,
          ssid: 'virtio',
          message: '$e',
        );
      }
    }
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
    String? security;
    if (snap.wpaStateToken == 'COMPLETED') {
      security = wpaSecurityLabel(
        snap.keyMgmt,
        privacy: snap.bssPrivacy,
      );
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
      macAddress: await _readMac(),
      linkSpeedMbps: await _readLinkSpeedMbps(),
      security: security,
    );
  }

  Future<String?> _readMac() async {
    try {
      return (await File('/sys/class/net/$iface/address').readAsString())
          .trim();
    } catch (_) {
      return null;
    }
  }

  Future<int?> _readLinkSpeedMbps() async {
    try {
      final s = await File('/sys/class/net/$iface/speed').readAsString();
      final v = int.tryParse(s.trim());
      if (v != null && v > 0) {
        return v;
      }
    } catch (_) {}
    try {
      final r = await _run(['iw', 'dev', iface, 'link'], log: false);
      return WifiLinkParse.linkSpeedMbpsFromIw(r.stdout as String? ?? '');
    } catch (_) {
      return null;
    }
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
    // Wait briefly if the radio is still coming up (Settings opens / toggle).
    if (_radio == WifiRadioState.starting) {
      final waitUntil = DateTime.now().add(const Duration(seconds: 5));
      while (_radio == WifiRadioState.starting &&
          DateTime.now().isBefore(waitUntil)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    if (_radio != WifiRadioState.on) {
      return const [];
    }
    if (!await _isIeee80211()) {
      // Virtio stand-in: no scan — use USB Wi‑Fi passthrough for real BSS lists.
      return const [];
    }
    await _ensureDbus();
    final wpa = _wpaDbus!;
    try {
      await wpa.scan(iface);
    } catch (e) {
      // Scan() often fails when a scan is already running — still read BSS.
      debugPrint('wifi: dbus scan trigger failed: $e');
    }

    List<WifiAccessPoint> mapRows(List<WpaScanResult> rows) {
      return [
        for (final r in rows)
          WifiAccessPoint(
            ssid: r.ssid,
            signalDbm: r.signalDbm,
            flags: r.requiresPsk ? '[WPA2-PSK-CCMP]' : '[ESS]',
            bssid: r.bssid,
          ),
      ];
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        final rows = await wpa.listScanResults(iface);
        if (rows.isNotEmpty) {
          return mapRows(rows);
        }
      } catch (_) {}
    }
    try {
      return mapRows(await wpa.listScanResults(iface));
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
    if (!await _isIeee80211()) {
      _emitConn(
        WifiConnectionState(
          phase: WifiConnectionPhase.failed,
          ssid: ssid,
          message:
              'virtio wlan0 has no 802.11 — plug a USB Wi‑Fi dongle (EMULATOR_USB)',
        ),
      );
      return;
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
      final hasPsk = psk != null && psk.isNotEmpty;
      if (hasPsk && vault != null) {
        await vault!.put(ssid, psk!);
      }
      // Multi-profile: connectNetwork keeps other saved SSIDs (My Networks).
      // mem_only_psk=1 (default) — vault holds the secret; conf stays scrubbed.
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
    final manualDns = cfg.dnsMode == WlanDnsMode.manual && cfg.dns.isNotEmpty
        ? cfg.dns
        : null;
    try {
      if (cfg.mode == WlanIpv4Mode.dhcp) {
        await apply.apply(
          iface: iface,
          mode: 'dhcp',
          routeMetric: _metric,
          dns: manualDns,
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
          dns: manualDns,
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
    if (!await _isIeee80211()) {
      _ipv4AppliedBssid = null;
      _emitConn(WifiConnectionState.disconnected);
      return;
    }
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
    if (!await _isIeee80211()) {
      if (_conn.ssid == ssid) {
        _ipv4AppliedBssid = null;
        _emitConn(WifiConnectionState.disconnected);
      }
      return;
    }
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
      try {
        await vault?.delete(ssid);
      } catch (e) {
        debugPrint('wifi: vault delete failed: $e');
      }
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
    if (!await _isIeee80211()) {
      return const [];
    }
    await _ensureDbus();
    final nets = await _wpaDbus!.listNetworks(iface);
    return nets
        .map(
          (n) => WifiSavedNetwork(
            networkId: n.networkId,
            ssid: n.ssid,
            autoJoin: n.enabled,
          ),
        )
        .toList();
  }

  @override
  Future<void> setAutoJoin(String ssid, {required bool enabled}) async {
    if (!await _isIeee80211()) {
      return;
    }
    await _ensureDbus();
    await _wpaDbus!.setAutoJoinBySsid(iface, ssid, enabled: enabled);
  }

  @override
  Future<bool> selectSaved(String ssid) async {
    if (_radio != WifiRadioState.on) {
      await setRadioEnabled(true);
      if (_radio != WifiRadioState.on) {
        return false;
      }
    }
    if (!await _isIeee80211()) {
      return false;
    }
    try {
      await NetworkdIpv4Apply().setLink(iface: iface, up: true);
    } catch (_) {}
    _ipv4AppliedBssid = null;
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.associating,
        ssid: ssid,
      ),
    );
    await _ensureDbus();
    String? vaultPsk;
    try {
      vaultPsk = await vault?.get(ssid);
    } catch (e) {
      debugPrint('wifi: vault get failed: $e');
    }
    final ok = await _wpaDbus!.selectSavedBySsid(
      iface,
      ssid,
      psk: vaultPsk,
    );
    if (!ok) {
      _emitConn(WifiConnectionState.disconnected);
      return false;
    }

    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final snap = await _wpaDbus!.readIface(iface);
      if (snap.wpaStateToken == 'COMPLETED') {
        _emitConn(
          WifiConnectionState(
            phase: WifiConnectionPhase.obtainingIp,
            ssid: ssid,
            bssid: snap.bssid,
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
          return true;
        }
        _ipv4AppliedBssid = snap.bssid?.toLowerCase();
        await _waitForIpv4(
          ssid: ssid,
          timeout: const Duration(seconds: 50),
        );
        return true;
      }
    }
    _emitConn(
      WifiConnectionState(
        phase: WifiConnectionPhase.failed,
        ssid: ssid,
        message: 'association timeout',
      ),
    );
    return true;
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
      if (!await _isIeee80211()) {
        if (wanted || await wifiRadio.isEnabled()) {
          // Bring-up re-probes IEEE after modem; may flip stand-in → real 802.11.
          await setRadioEnabled(true);
        }
        return;
      }
      if (await _wpaLive()) {
        _stopWantedWatch();
        _emitRadio(WifiRadioState.on);
        await _prepareVaultAndInject();
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
