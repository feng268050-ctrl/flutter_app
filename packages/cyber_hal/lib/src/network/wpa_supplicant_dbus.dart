import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:cyber_hal/src/network/wifi_multi_profile_policy.dart';

/// Thin client for `fi.w1.wpa_supplicant1` (requires `wpa_supplicant -u`).
class WpaSupplicantDbus {
  WpaSupplicantDbus({
    DBusClient? client,
    this.busName = 'fi.w1.wpa_supplicant1',
  }) : _client = client ?? DBusClient.system(),
       _ownsClient = client == null;

  final DBusClient _client;
  final bool _ownsClient;
  final String busName;

  DBusObjectPath? _ifacePath;
  StreamSubscription<DBusPropertiesChangedSignal>? _propsSub;
  StreamSubscription<DBusNameOwnerChangedEvent>? _ownerSub;

  DBusClient get client => _client;

  /// Attach to [iface] Interface object and invoke [onChange] on property updates.
  /// Also fires once after a successful attach (reconciliation Get).
  Future<void> watchInterface(
    String iface, {
    required void Function() onChange,
  }) async {
    await cancelWatch();
    _ownerSub = _client.nameOwnerChanged.listen((ev) {
      if (ev.name != busName) {
        return;
      }
      if (ev.newOwner != null && ev.newOwner!.isNotEmpty) {
        unawaited(_attachIface(iface, onChange));
      }
    });
    await _attachIface(iface, onChange);
  }

  Future<void> _attachIface(String iface, void Function() onChange) async {
    try {
      _ifacePath = await getInterfacePath(iface);
    } catch (_) {
      // wpa not up yet — NameOwnerChanged / later retry will attach.
      return;
    }
    final obj = DBusRemoteObject(
      _client,
      name: busName,
      path: _ifacePath!,
    );
    await _propsSub?.cancel();
    _propsSub = obj.propertiesChanged.listen((sig) {
      if (sig.propertiesInterface == 'fi.w1.wpa_supplicant1.Interface' ||
          sig.propertiesInterface == 'fi.w1.wpa_supplicant1.Interface.WPS' ||
          sig.invalidatedProperties.isNotEmpty) {
        onChange();
      }
    });
    onChange();
  }

  Future<DBusObjectPath> getInterfacePath(String iface) async {
    final root = DBusRemoteObject(
      _client,
      name: busName,
      path: DBusObjectPath('/fi/w1/wpa_supplicant1'),
    );
    final r = await root.callMethod(
      'fi.w1.wpa_supplicant1',
      'GetInterface',
      [DBusString(iface)],
      replySignature: DBusSignature('o'),
    );
    return r.returnValues[0] as DBusObjectPath;
  }

  /// Snapshot of Interface string/int properties used by Demo status.
  Future<WpaIfaceSnapshot> readIface(String iface) async {
    final path = _ifacePath ?? await getInterfacePath(iface);
    _ifacePath = path;
    final obj = DBusRemoteObject(_client, name: busName, path: path);
    final state = await _getString(obj, 'fi.w1.wpa_supplicant1.Interface', 'State');
    String? ssid;
    String? bssid;
    int? freq;
    int? signal;
    var keyMgmt = const <String>[];
    var bssPrivacy = false;
    try {
      final bssPath = await obj.getProperty(
        'fi.w1.wpa_supplicant1.Interface',
        'CurrentBSS',
        signature: DBusSignature('o'),
      );
      if (bssPath is DBusObjectPath && bssPath.value != '/') {
        final bss = DBusRemoteObject(_client, name: busName, path: bssPath);
        ssid = await _readSsid(bss);
        bssid = await _readBssid(bss);
        freq = await _getUint(bss, 'fi.w1.wpa_supplicant1.BSS', 'Frequency');
        signal = await _getInt(bss, 'fi.w1.wpa_supplicant1.BSS', 'Signal');
        keyMgmt = await _readBssKeyMgmt(bss);
        bssPrivacy = await _bssPrivacyImpliesWep(bss, keyMgmt);
      }
    } catch (_) {}
    return WpaIfaceSnapshot(
      state: state ?? '',
      ssid: ssid,
      bssid: bssid,
      frequencyMhz: freq,
      signalDbm: signal,
      keyMgmt: keyMgmt,
      bssPrivacy: bssPrivacy,
    );
  }

  Future<String?> _readSsid(DBusRemoteObject bss) async {
    try {
      final v = await bss.getProperty(
        'fi.w1.wpa_supplicant1.BSS',
        'SSID',
        signature: DBusSignature('ay'),
      );
      if (v is DBusArray) {
        final bytes = v.mapByte().toList();
        if (bytes.isEmpty) {
          return null;
        }
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _readBssid(DBusRemoteObject bss) async {
    try {
      final v = await bss.getProperty('fi.w1.wpa_supplicant1.BSS', 'BSSID');
      if (v is DBusString) {
        return v.value;
      }
      if (v is DBusArray) {
        final bytes = v.mapByte().toList();
        if (bytes.length == 6) {
          return bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(':');
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _getString(
    DBusRemoteObject obj,
    String iface,
    String name,
  ) async {
    try {
      final v = await obj.getProperty(iface, name, signature: DBusSignature('s'));
      if (v is DBusString) {
        return v.value;
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _getUint(
    DBusRemoteObject obj,
    String iface,
    String name,
  ) async {
    try {
      final v = await obj.getProperty(iface, name);
      if (v is DBusUint16) {
        return v.value;
      }
      if (v is DBusUint32) {
        return v.value;
      }
      if (v is DBusInt16) {
        return v.value;
      }
      if (v is DBusInt32) {
        return v.value;
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _getInt(
    DBusRemoteObject obj,
    String iface,
    String name,
  ) async {
    try {
      final v = await obj.getProperty(iface, name);
      if (v is DBusInt16) {
        return v.value;
      }
      if (v is DBusInt32) {
        return v.value;
      }
      if (v is DBusByte) {
        return v.value;
      }
    } catch (_) {}
    return null;
  }

  // --- L2 commands (D11b): prefer these over wpa_cli ---

  Future<DBusRemoteObject> _ifaceObject(String iface) async {
    final path = _ifacePath ?? await getInterfacePath(iface);
    _ifacePath = path;
    return DBusRemoteObject(_client, name: busName, path: path);
  }

  /// Trigger an active scan.
  Future<void> scan(String iface, {String type = 'active'}) async {
    final obj = await _ifaceObject(iface);
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'Scan',
      [
        DBusDict.stringVariant({
          'Type': DBusString(type),
        }),
      ],
      replySignature: DBusSignature(''),
    );
  }

  /// BSS list after a scan (SSID / signal / whether a PSK is required).
  Future<List<WpaScanResult>> listScanResults(String iface) async {
    final obj = await _ifaceObject(iface);
    final v = await obj.getProperty(
      'fi.w1.wpa_supplicant1.Interface',
      'BSSs',
      signature: DBusSignature('ao'),
    );
    if (v is! DBusArray) {
      return const [];
    }
    final out = <WpaScanResult>[];
    for (final child in v.children) {
      if (child is! DBusObjectPath || child.value == '/') {
        continue;
      }
      final bss = DBusRemoteObject(_client, name: busName, path: child);
      final ssid = await _readSsid(bss);
      if (ssid == null || ssid.isEmpty) {
        continue;
      }
      final signal = await _getInt(bss, 'fi.w1.wpa_supplicant1.BSS', 'Signal');
      final keyMgmt = await _readBssKeyMgmt(bss);
      final requiresPsk = wpaKeyMgmtRequiresPsk(keyMgmt) ||
          await _bssPrivacyImpliesWep(bss, keyMgmt);
      final bssid = await _readBssid(bss);
      out.add(
        WpaScanResult(
          ssid: ssid,
          signalDbm: signal,
          secured: requiresPsk,
          keyMgmt: keyMgmt,
          bssid: bssid,
        ),
      );
    }
    // Prefer strongest per SSID.
    final best = <String, WpaScanResult>{};
    for (final ap in out) {
      final prev = best[ap.ssid];
      if (prev == null ||
          (ap.signalDbm ?? -999) > (prev.signalDbm ?? -999)) {
        best[ap.ssid] = ap;
      }
    }
    return best.values.toList();
  }

  /// KeyMgmt strings from BSS WPA + RSN dicts (may be empty for open / WEP).
  Future<List<String>> _readBssKeyMgmt(DBusRemoteObject bss) async {
    final out = <String>[];
    for (final prop in <String>['WPA', 'RSN']) {
      try {
        final raw = await bss.getProperty('fi.w1.wpa_supplicant1.BSS', prop);
        out.addAll(_keyMgmtFromSecurityDict(raw));
      } catch (_) {}
    }
    return out;
  }

  /// WEP often has empty KeyMgmt but Privacy=true (WPA/RSN dicts may still
  /// be non-empty shells — never treat "dict non-empty" as PSK).
  Future<bool> _bssPrivacyImpliesWep(
    DBusRemoteObject bss,
    List<String> keyMgmt,
  ) async {
    if (keyMgmt.isNotEmpty) {
      return false;
    }
    try {
      final priv = await bss.getProperty(
        'fi.w1.wpa_supplicant1.BSS',
        'Privacy',
      );
      return priv is DBusBoolean && priv.value;
    } catch (_) {
      return false;
    }
  }

  static List<String> _keyMgmtFromSecurityDict(DBusValue raw) {
    final dict = raw is DBusVariant ? raw.value : raw;
    if (dict is! DBusDict || dict.children.isEmpty) {
      return const [];
    }
    try {
      final mapped = dict.mapStringVariant();
      final km = mapped['KeyMgmt'];
      if (km is! DBusArray) {
        return const [];
      }
      return km.children
          .map((e) {
            if (e is DBusString) {
              return e.value;
            }
            if (e is DBusVariant && e.value is DBusString) {
              return (e.value as DBusString).value;
            }
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Configured networks on [iface] (D-Bus `Networks` + SSID / Enabled).
  Future<List<WpaConfiguredNetwork>> listNetworks(String iface) async {
    final obj = await _ifaceObject(iface);
    final v = await obj.getProperty(
      'fi.w1.wpa_supplicant1.Interface',
      'Networks',
      signature: DBusSignature('ao'),
    );
    if (v is! DBusArray) {
      return const [];
    }
    final out = <WpaConfiguredNetwork>[];
    var index = 0;
    for (final child in v.children) {
      if (child is! DBusObjectPath) {
        continue;
      }
      final info = await _readNetworkInfo(child);
      if (info == null ||
          info.ssid.isEmpty ||
          info.ssid == 'any') {
        index++;
        continue;
      }
      out.add(
        WpaConfiguredNetwork(
          path: child,
          networkId: index,
          ssid: info.ssid,
          enabled: info.enabled,
        ),
      );
      index++;
    }
    return out;
  }

  Future<({String ssid, bool enabled})?> _readNetworkInfo(
    DBusObjectPath path,
  ) async {
    final ssid = await _readNetworkSsid(path);
    if (ssid == null) {
      return null;
    }
    var enabled = true;
    try {
      final net = DBusRemoteObject(_client, name: busName, path: path);
      final en = await net.getProperty(
        'fi.w1.wpa_supplicant1.Network',
        'Enabled',
        signature: DBusSignature('b'),
      );
      if (en is DBusBoolean) {
        enabled = en.value;
      }
    } catch (_) {}
    return (ssid: ssid, enabled: enabled);
  }

  Future<String?> _readNetworkSsid(DBusObjectPath path) async {
    try {
      final net = DBusRemoteObject(_client, name: busName, path: path);
      final props = await net.getProperty(
        'fi.w1.wpa_supplicant1.Network',
        'Properties',
        signature: DBusSignature('a{sv}'),
      );
      final dict = props is DBusVariant ? props.value : props;
      if (dict is! DBusDict) {
        return null;
      }
      final mapped = dict.mapStringVariant();
      var raw = mapped['ssid'];
      if (raw is DBusVariant) {
        raw = raw.value;
      }
      if (raw is DBusString) {
        var s = raw.value;
        if (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
          s = s.substring(1, s.length - 1);
        }
        return s;
      }
      if (raw is DBusArray) {
        final bytes = raw.mapByte().toList();
        if (bytes.isEmpty) {
          return null;
        }
        return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (_) {}
    return null;
  }

  Future<void> removeNetwork(String iface, DBusObjectPath path) async {
    final obj = await _ifaceObject(iface);
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'RemoveNetwork',
      [path],
      replySignature: DBusSignature(''),
    );
  }

  /// Remove configured networks whose SSID matches [ssid] (exact).
  Future<int> removeNetworksBySsid(String iface, String ssid) async {
    final target = ssid.trim();
    if (target.isEmpty) {
      return 0;
    }
    final nets = await listNetworks(iface);
    var n = 0;
    for (final net in nets.where((e) => e.ssid == target)) {
      await removeNetwork(iface, net.path);
      n++;
    }
    return n;
  }

  /// Set Auto Join for all configured networks matching [ssid].
  ///
  /// Maps to D-Bus Network.Enabled (persisted via SaveConfig as disabled=0/1).
  Future<int> setAutoJoinBySsid(
    String iface,
    String ssid, {
    required bool enabled,
  }) async {
    final target = ssid.trim();
    if (target.isEmpty) {
      return 0;
    }
    final nets = await listNetworks(iface);
    var n = 0;
    for (final net in nets.where((e) => e.ssid == target)) {
      await setNetworkEnabled(net.path, enabled);
      n++;
    }
    if (n > 0) {
      await saveConfig(iface);
    }
    return n;
  }

  Future<void> setNetworkEnabled(DBusObjectPath path, bool enabled) async {
    final net = DBusRemoteObject(_client, name: busName, path: path);
    await net.setProperty(
      'fi.w1.wpa_supplicant1.Network',
      'Enabled',
      DBusBoolean(enabled),
    );
  }

  Future<void> selectNetwork(String iface, DBusObjectPath path) async {
    final obj = await _ifaceObject(iface);
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'SelectNetwork',
      [path],
      replySignature: DBusSignature(''),
    );
  }

  /// Enable + SelectNetwork for an existing configured SSID (no credential rewrite).
  ///
  /// Restores Auto Join ([Enabled]) on sibling networks afterward — SelectNetwork
  /// disables others as a side effect.
  Future<bool> selectSavedBySsid(String iface, String ssid) async {
    final target = ssid.trim();
    if (target.isEmpty) {
      return false;
    }
    final nets = await listNetworks(iface);
    final match = nets.where((e) => e.ssid == target);
    if (match.isEmpty) {
      return false;
    }
    final keepEnabledPaths = WifiMultiProfilePolicy.siblingPathsToRestore(
      before: nets.map(
        (n) => (path: n.path.value, ssid: n.ssid, enabled: n.enabled),
      ),
      connectingSsid: target,
    );
    final net = match.first;
    await setNetworkEnabled(net.path, true);
    await selectNetwork(iface, net.path);
    await _restoreEnabledNetworks(
      iface,
      keepEnabledPaths: keepEnabledPaths,
      exceptPath: net.path,
    );
    try {
      await saveConfig(iface);
    } catch (_) {}
    return true;
  }

  /// After [SelectNetwork], re-enable sibling networks that were Auto Join on.
  Future<void> _restoreEnabledNetworks(
    String iface, {
    required Set<String> keepEnabledPaths,
    required DBusObjectPath exceptPath,
  }) async {
    if (keepEnabledPaths.isEmpty) {
      return;
    }
    final nets = await listNetworks(iface);
    for (final n in nets) {
      if (n.path.value == exceptPath.value) {
        continue;
      }
      if (!keepEnabledPaths.contains(n.path.value)) {
        continue;
      }
      try {
        await setNetworkEnabled(n.path, true);
      } catch (_) {}
    }
  }

  /// Disable CurrentNetwork (if any) so Disconnect does not immediately reassoc.
  Future<void> disableCurrentNetwork(String iface) async {
    final obj = await _ifaceObject(iface);
    try {
      final cur = await obj.getProperty(
        'fi.w1.wpa_supplicant1.Interface',
        'CurrentNetwork',
        signature: DBusSignature('o'),
      );
      if (cur is! DBusObjectPath || cur.value == '/') {
        return;
      }
      final net = DBusRemoteObject(_client, name: busName, path: cur);
      await net.setProperty(
        'fi.w1.wpa_supplicant1.Network',
        'Enabled',
        const DBusBoolean(false),
      );
    } catch (_) {}
  }

  Future<void> removeAllNetworks(String iface) async {
    final obj = await _ifaceObject(iface);
    try {
      await obj.callMethod(
        'fi.w1.wpa_supplicant1.Interface',
        'RemoveAllNetworks',
        const [],
        replySignature: DBusSignature(''),
      );
      return;
    } catch (_) {
      // Older builds may lack RemoveAllNetworks — fall back to iterating.
    }
    final v = await obj.getProperty(
      'fi.w1.wpa_supplicant1.Interface',
      'Networks',
      signature: DBusSignature('ao'),
    );
    if (v is! DBusArray) {
      return;
    }
    for (final child in v.children) {
      if (child is DBusObjectPath) {
        await obj.callMethod(
          'fi.w1.wpa_supplicant1.Interface',
          'RemoveNetwork',
          [child],
          replySignature: DBusSignature(''),
        );
      }
    }
  }

  /// Add or replace one SSID profile, SelectNetwork, SaveConfig. Returns path.
  ///
  /// **Multi-profile:** other saved SSIDs are kept. Matching [ssid] entries are
  /// replaced so credentials/flags stay fresh. [SelectNetwork] disables siblings
  /// temporarily; Auto Join ([Enabled]=true) is restored on those siblings after
  /// select so My Networks remains multi-entry.
  ///
  /// [hidden] sets `scan_ssid=1` so wpa actively probes non-broadcast SSIDs.
  /// [requiresPsk] rejects empty PSK instead of falling through to `key_mgmt=NONE`.
  Future<DBusObjectPath> connectNetwork(
    String iface, {
    required String ssid,
    String? psk,
    String? bssid,
    bool hidden = false,
    bool requiresPsk = false,
  }) async {
    final obj = await _ifaceObject(iface);
    final target = ssid.trim();
    final existing = await listNetworks(iface);
    final keepEnabledPaths = WifiMultiProfilePolicy.siblingPathsToRestore(
      before: existing.map(
        (n) => (path: n.path.value, ssid: n.ssid, enabled: n.enabled),
      ),
      connectingSsid: target,
    );

    // Replace prior profile(s) for this SSID only — keep other remembered nets.
    for (final n in existing.where((e) => e.ssid == target)) {
      await removeNetwork(iface, n.path);
    }

    final conf = <String, DBusValue>{
      'ssid': DBusString(target.isEmpty ? ssid : target),
    };
    if (hidden) {
      // uint32 — required for hidden / non-broadcast SSIDs.
      conf['scan_ssid'] = DBusUint32(1);
    }
    if (bssid != null && bssid.isNotEmpty) {
      conf['bssid'] = DBusString(bssid);
    }
    final hasPsk = psk != null && psk.isNotEmpty;
    if (requiresPsk && !hasPsk) {
      throw ArgumentError('PSK required for secured network');
    }
    if (hasPsk) {
      conf['psk'] = DBusString(psk);
    } else {
      conf['key_mgmt'] = DBusString('NONE');
    }
    final add = await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'AddNetwork',
      [DBusDict.stringVariant(conf)],
      replySignature: DBusSignature('o'),
    );
    final path = add.returnValues[0] as DBusObjectPath;
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'SelectNetwork',
      [path],
      replySignature: DBusSignature(''),
    );
    await _restoreEnabledNetworks(
      iface,
      keepEnabledPaths: keepEnabledPaths,
      exceptPath: path,
    );
    // Kick an active Probe Request for the non-broadcast SSID.
    if (hidden) {
      try {
        await scanHidden(iface, ssid);
      } catch (_) {
        try {
          await scan(iface);
        } catch (_) {}
      }
    }
    try {
      await obj.callMethod(
        'fi.w1.wpa_supplicant1.Interface',
        'SaveConfig',
        const [],
        replySignature: DBusSignature(''),
      );
    } catch (_) {}
    return path;
  }

  /// Active scan that includes [ssid] in Probe Request (hidden / directed scan).
  Future<void> scanHidden(String iface, String ssid) async {
    final obj = await _ifaceObject(iface);
    final ssidBytes = DBusArray.byte(utf8.encode(ssid));
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'Scan',
      [
        DBusDict.stringVariant({
          'Type': DBusString('active'),
          'SSIDs': DBusArray(DBusSignature('ay'), [ssidBytes]),
        }),
      ],
      replySignature: DBusSignature(''),
    );
  }

  Future<void> saveConfig(String iface) async {
    final obj = await _ifaceObject(iface);
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'SaveConfig',
      const [],
      replySignature: DBusSignature(''),
    );
  }

  Future<void> disconnect(String iface) async {
    final obj = await _ifaceObject(iface);
    await obj.callMethod(
      'fi.w1.wpa_supplicant1.Interface',
      'Disconnect',
      const [],
      replySignature: DBusSignature(''),
    );
  }

  Future<void> cancelWatch() async {
    await _propsSub?.cancel();
    _propsSub = null;
    await _ownerSub?.cancel();
    _ownerSub = null;
  }

  Future<void> close() async {
    await cancelWatch();
    if (_ownsClient) {
      await _client.close();
    }
  }
}

final class WpaConfiguredNetwork {
  const WpaConfiguredNetwork({
    required this.path,
    required this.networkId,
    required this.ssid,
    this.enabled = true,
  });

  final DBusObjectPath path;

  /// Stable index within the current Networks list (not wpa_cli id).
  final int networkId;
  final String ssid;

  /// D-Bus Network.Enabled — false means Auto Join off / disabled.
  final bool enabled;
}

final class WpaIfaceSnapshot {
  const WpaIfaceSnapshot({
    required this.state,
    this.ssid,
    this.bssid,
    this.frequencyMhz,
    this.signalDbm,
    this.keyMgmt = const [],
    this.bssPrivacy = false,
  });

  /// wpa D-Bus Interface.State (e.g. completed, scanning, disconnected).
  final String state;
  final String? ssid;
  final String? bssid;
  final int? frequencyMhz;
  final int? signalDbm;
  final List<String> keyMgmt;
  final bool bssPrivacy;

  /// Map D-Bus State → legacy wpa_cli-style uppercase token for phase helpers.
  String get wpaStateToken {
    switch (state.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'associating':
        return 'ASSOCIATING';
      case 'associated':
        return 'ASSOCIATED';
      case 'authenticating':
        return 'AUTHENTICATING';
      case '4way_handshake':
        return '4WAY_HANDSHAKE';
      case 'group_handshake':
        return 'GROUP_HANDSHAKE';
      case 'disconnected':
        return 'DISCONNECTED';
      case 'inactive':
        return 'INACTIVE';
      case 'interface_disabled':
        return 'INTERFACE_DISABLED';
      case 'scanning':
        return 'SCANNING';
      default:
        return state.toUpperCase();
    }
  }
}

final class WpaScanResult {
  const WpaScanResult({
    required this.ssid,
    this.signalDbm,
    this.secured = false,
    this.keyMgmt = const [],
    this.bssid,
  });

  final String ssid;
  final int? signalDbm;

  /// True when the UI should ask for a PSK / WEP key (not mere "RSN dict present").
  final bool secured;
  final List<String> keyMgmt;
  final String? bssid;

  /// Alias for [secured] — open / OWE / enterprise-without-PSK → false.
  bool get requiresPsk => secured;
}

/// Whether wpa KeyMgmt tokens require a user passphrase (PSK / SAE / WEP).
///
/// Open and OWE do **not**. WPA/RSN D-Bus dicts may be non-empty shells with
/// empty KeyMgmt — callers must not treat "dict non-empty" as secured.
bool wpaKeyMgmtRequiresPsk(Iterable<String> keyMgmt) {
  for (final raw in keyMgmt) {
    final k = raw.toLowerCase().trim();
    if (k.isEmpty || k == 'none' || k == 'wpa-none' || k == 'owe' || k == 'wps') {
      continue;
    }
    if (k.contains('psk') || k.contains('sae') || k.contains('wep')) {
      return true;
    }
  }
  return false;
}

/// User-facing security label from wpa KeyMgmt tokens (Open / WEP / WPA2 / WPA3 / OWE).
String? wpaSecurityLabel(
  Iterable<String> keyMgmt, {
  bool privacy = false,
}) {
  final keys = keyMgmt
      .map((k) => k.toLowerCase().trim())
      .where((k) => k.isNotEmpty && k != 'wps')
      .toList();
  if (keys.any((k) => k.contains('sae'))) {
    return 'WPA3';
  }
  if (keys.any((k) => k.contains('wep'))) {
    return 'WEP';
  }
  if (keys.any((k) => k.contains('psk') || k.contains('eap') || k.startsWith('wpa-'))) {
    return 'WPA2';
  }
  if (keys.any((k) => k == 'owe')) {
    return 'OWE';
  }
  if (keys.isEmpty || keys.every((k) => k == 'none' || k == 'wpa-none')) {
    return privacy ? 'WEP' : 'Open';
  }
  return null;
}

/// Parse networkd `Addresses` a(iiay) into IPv4 host strings + prefix.
List<({String address, int prefix})> parseNetworkdAddresses(DBusValue? value) {
  final out = <({String address, int prefix})>[];
  if (value is! DBusArray) {
    return out;
  }
  for (final entry in value.children) {
    if (entry is! DBusStruct || entry.children.length < 3) {
      continue;
    }
    final family = (entry.children[0] as DBusInt32).value;
    final prefix = (entry.children[1] as DBusInt32).value;
    final addrVal = entry.children[2];
    if (family != 2 || addrVal is! DBusArray) {
      continue; // AF_INET only for Demo IPv4 line
    }
    final bytes = Uint8List.fromList(
      addrVal.children.map((e) => (e as DBusByte).value).toList(),
    );
    if (bytes.length != 4) {
      continue;
    }
    out.add((
      address: '${bytes[0]}.${bytes[1]}.${bytes[2]}.${bytes[3]}',
      prefix: prefix,
    ));
  }
  return out;
}
