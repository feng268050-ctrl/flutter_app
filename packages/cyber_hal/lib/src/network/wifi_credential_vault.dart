import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/secrets/kek_provider.dart';

/// Purpose label bound into AAD for every Wi‑Fi PSK seal (`wifi-psk\\0ssid`).
const wifiVaultAadPurpose = 'wifi-psk';

/// Current on-disk vault document version.
const wifiVaultFormatVersion = 1;

/// Default vault path under the wpa userdata tree.
const wifiCredentialVaultDefaultPath =
    '/var/lib/wpa_supplicant/credentials.vault';

/// Build AAD for a per-SSID Wi‑Fi PSK seal.
Uint8List wifiVaultAadForSsid(String ssid) {
  return Uint8List.fromList(utf8.encode('$wifiVaultAadPurpose\x00$ssid'));
}

/// Versioned vault envelope: `ssid → sealed blob` (opaque ciphertext).
///
/// Encoding is JSON for host inspectability; secrets live only inside sealed
/// blobs produced by [KekProvider].
final class WifiVaultDocument {
  const WifiVaultDocument({
    this.version = wifiVaultFormatVersion,
    this.entries = const {},
  });

  final int version;

  /// Map of SSID → opaque sealed blob bytes.
  final Map<String, Uint8List> entries;

  WifiVaultDocument copyWith({
    int? version,
    Map<String, Uint8List>? entries,
  }) {
    return WifiVaultDocument(
      version: version ?? this.version,
      entries: entries ?? this.entries,
    );
  }

  /// Encode to UTF-8 JSON bytes.
  Uint8List encode() {
    final map = <String, String>{};
    for (final e in entries.entries) {
      map[e.key] = base64Encode(e.value);
    }
    final json = <String, Object?>{
      'v': version,
      'entries': map,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  /// Decode UTF-8 JSON bytes produced by [encode].
  static WifiVaultDocument decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      return const WifiVaultDocument();
    }
    final Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw HalIoException('wifi vault: invalid JSON ($e)');
    }
    if (raw is! Map) {
      throw const HalIoException('wifi vault: root must be object');
    }
    final v = raw['v'];
    final version = v is int ? v : int.tryParse('$v') ?? 0;
    if (version < 1 || version > wifiVaultFormatVersion) {
      throw HalIoException('wifi vault: unsupported version $version');
    }
    final entriesRaw = raw['entries'];
    if (entriesRaw == null) {
      return WifiVaultDocument(version: version);
    }
    if (entriesRaw is! Map) {
      throw const HalIoException('wifi vault: entries must be object');
    }
    final entries = <String, Uint8List>{};
    for (final e in entriesRaw.entries) {
      final ssid = '${e.key}';
      final val = e.value;
      if (val is! String) {
        throw HalIoException('wifi vault: entry for "$ssid" not base64 string');
      }
      try {
        entries[ssid] = base64Decode(val);
      } catch (err) {
        throw HalIoException('wifi vault: entry for "$ssid" bad base64 ($err)');
      }
    }
    return WifiVaultDocument(version: version, entries: entries);
  }
}

/// Wi‑Fi credential vault: store/get/delete PSKs sealed via abstract Secrets.
///
/// Does **not** construct a concrete Tee / software KEK — callers inject
/// [KekProvider] (typically [BoardBindings.secrets]).
final class WifiCredentialVault {
  WifiCredentialVault({
    required KekProvider secrets,
    this.path = wifiCredentialVaultDefaultPath,
  }) : _secrets = secrets;

  final KekProvider _secrets;
  final String path;

  /// Backend id for diagnostics (from Secrets).
  String get secretsBackendId => _secrets.backendId;

  Future<WifiVaultDocument> _load() async {
    final f = File(path);
    if (!await f.exists()) {
      return const WifiVaultDocument();
    }
    final bytes = await f.readAsBytes();
    if (bytes.isEmpty) {
      return const WifiVaultDocument();
    }
    return WifiVaultDocument.decode(bytes);
  }

  Future<void> _save(WifiVaultDocument doc) async {
    final f = File(path);
    await f.parent.create(recursive: true);
    final tmp = File('$path.tmp');
    final bytes = doc.encode();
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(path);
    try {
      await Process.run('chmod', ['600', path]);
    } catch (_) {
      // Best-effort on hosts without chmod semantics.
    }
  }

  /// Seal and store [psk] for [ssid] (replaces any prior entry).
  Future<void> put(String ssid, String psk) async {
    final key = ssid.trim();
    if (key.isEmpty) {
      throw ArgumentError('ssid must be non-empty');
    }
    if (psk.isEmpty) {
      throw ArgumentError('psk must be non-empty');
    }
    final plain = Uint8List.fromList(utf8.encode(psk));
    final blob = await _secrets.seal(
      plaintext: plain,
      aad: wifiVaultAadForSsid(key),
    );
    // Clear local copy of plaintext bytes where practical.
    plain.fillRange(0, plain.length, 0);
    final doc = await _load();
    final next = Map<String, Uint8List>.from(doc.entries)..[key] = blob;
    await _save(doc.copyWith(entries: next));
  }

  /// Unseal PSK for [ssid], or null if missing.
  Future<String?> get(String ssid) async {
    final key = ssid.trim();
    if (key.isEmpty) {
      return null;
    }
    final doc = await _load();
    final blob = doc.entries[key];
    if (blob == null) {
      return null;
    }
    final plain = await _secrets.unseal(
      blob: blob,
      aad: wifiVaultAadForSsid(key),
    );
    return utf8.decode(plain, allowMalformed: false);
  }

  /// Remove vault entry for [ssid] (no-op if absent).
  Future<void> delete(String ssid) async {
    final key = ssid.trim();
    if (key.isEmpty) {
      return;
    }
    final doc = await _load();
    if (!doc.entries.containsKey(key)) {
      return;
    }
    final next = Map<String, Uint8List>.from(doc.entries)..remove(key);
    await _save(doc.copyWith(entries: next));
  }

  Future<bool> contains(String ssid) async {
    final key = ssid.trim();
    if (key.isEmpty) {
      return false;
    }
    final doc = await _load();
    return doc.entries.containsKey(key);
  }

  Future<Set<String>> listSsids() async {
    final doc = await _load();
    return doc.entries.keys.toSet();
  }
}
