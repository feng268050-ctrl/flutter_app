import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/device/display_value.dart';

/// lws-ui [CameraConfig] credentials for IPC HTTP (`admin` / `admin`).
const kCameraHttpUser = 'admin';
const kCameraHttpPassword = 'admin';

/// HTTP Basic value matching lws-ui `CameraConfig.basicAuthorization()`.
String cameraHttpBasicAuthorization({
  String user = kCameraHttpUser,
  String password = kCameraHttpPassword,
}) {
  final raw = base64Encode(utf8.encode('$user:$password'));
  return 'Basic $raw';
}

/// Normalizes camera `appVersion` for UI / WS (lws-ui `parseCameraAppVersionDisplayValue`).
///
/// Example: `v1.0.5 build20251127` → `1.0.5`.
String parseCameraAppVersionDisplay(String? rawAppVersion) {
  if (rawAppVersion == null) {
    return kUnavailableDisplay;
  }
  var trimmed = rawAppVersion.trim();
  if (trimmed.isEmpty) {
    return kUnavailableDisplay;
  }
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    trimmed = trimmed.substring(1).trim();
  }
  final lower = trimmed.toLowerCase();
  final buildIdx = lower.indexOf(' build');
  if (buildIdx >= 0) {
    trimmed = trimmed.substring(0, buildIdx).trim();
  }
  return trimmed.isEmpty ? kUnavailableDisplay : trimmed;
}

/// Cached camera software version from HTTP `GET …/System/deviceinfo`.
///
/// Requires Basic Auth with header name `Authorization` (MJPG-Streamer is
/// case-sensitive; Dart [HttpHeaders] lowercases by default).
final class CameraDeviceInfoCache {
  CameraDeviceInfoCache({
    this.port = 9000,
    this.path = '/System/deviceinfo',
    this.timeout = const Duration(seconds: 3),
    String authorization = '',
    HttpClient? httpClient,
  })  : _http = httpClient ?? HttpClient(),
        _authorization = authorization.isEmpty
            ? cameraHttpBasicAuthorization()
            : authorization {
    // Camera is on the LAN segment; never consult http_proxy.
    _http.findProxy = (_) => 'DIRECT';
    _http.connectionTimeout = timeout;
  }

  final int port;
  final String path;
  final Duration timeout;
  final String _authorization;
  final HttpClient _http;

  String? _cached;
  String? _cachedHost;
  Future<String>? _inFlight;

  String? _cachedRaw;
  String get currentOrDash => _cached ?? kUnavailableDisplay;

  /// Last successful raw `appVersion` (for SemVer+build upgrade gate).
  String? get currentRawOrNull => _cachedRaw;

  /// Drop cached success so the next [fetch] hits the network.
  void invalidate() {
    _cached = null;
    _cachedRaw = null;
    _cachedHost = null;
  }

  Future<String> fetch(String cameraHost) async {
    final raw = await fetchRawAppVersion(cameraHost);
    if (raw == null) {
      return kUnavailableDisplay;
    }
    return parseCameraAppVersionDisplay(raw);
  }

  /// Raw `appVersion` / `app_version` from deviceinfo, or null if unreachable.
  Future<String?> fetchRawAppVersion(String cameraHost) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      _cached = null;
      _cachedRaw = null;
      _cachedHost = null;
      return null;
    }
    if (_cachedHost == host &&
        _cachedRaw != null &&
        _cachedRaw!.isNotEmpty) {
      return _cachedRaw;
    }
    final existing = _inFlight;
    if (existing != null && _cachedHost == host) {
      await existing;
      return _cachedRaw;
    }
    final done = _fetchOnce(host);
    _inFlight = done;
    try {
      await done;
      return _cachedRaw;
    } finally {
      if (identical(_inFlight, done)) {
        _inFlight = null;
      }
    }
  }

  Future<String> _fetchOnce(String host) async {
    try {
      final uri = Uri(
        scheme: 'http',
        host: host,
        port: port,
        path: path,
      );
      debugPrint('camera-deviceinfo: GET $uri');
      final req = await _http.getUrl(uri).timeout(timeout);
      // MJPG-Streamer treats header names case-sensitively; keep "Authorization".
      req.headers.set(
        'Authorization',
        _authorization,
        preserveHeaderCase: true,
      );
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint(
          'camera-deviceinfo: HTTP ${res.statusCode} from $host',
        );
        await res.drain<void>();
        final viaWget = await _wgetFallbackRaw(host);
        if (viaWget != null) {
          _storeSuccess(host, viaWget);
          debugPrint('camera-deviceinfo: ok via wget → $viaWget');
          return parseCameraAppVersionDisplay(viaWget);
        }
        return kUnavailableDisplay;
      }
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return kUnavailableDisplay;
      }
      final raw = decoded['appVersion']?.toString() ??
          decoded['app_version']?.toString();
      final version = parseCameraAppVersionDisplay(raw);
      if (version == kUnavailableDisplay || raw == null || raw.trim().isEmpty) {
        return kUnavailableDisplay;
      }
      _storeSuccess(host, raw.trim());
      debugPrint('camera-deviceinfo: ok → $version (raw=$raw)');
      return version;
    } catch (e, st) {
      debugPrint('camera-deviceinfo: $e\n$st');
      try {
        final viaWget = await _wgetFallbackRaw(host);
        if (viaWget != null) {
          _storeSuccess(host, viaWget);
          debugPrint('camera-deviceinfo: ok via wget → $viaWget');
          return parseCameraAppVersionDisplay(viaWget);
        }
      } catch (_) {}
      return kUnavailableDisplay;
    }
  }

  void _storeSuccess(String host, String raw) {
    _cachedRaw = raw;
    _cached = parseCameraAppVersionDisplay(raw);
    _cachedHost = host;
  }

  /// BusyBox wget backup when Dart [HttpClient] auth headers misbehave.
  Future<String?> _wgetFallbackRaw(String host) async {
    try {
      final r = await Process.run('wget', <String>[
        '-qO-',
        '-T',
        '${timeout.inSeconds}',
        '--header',
        'Authorization: $_authorization',
        'http://$host:$port$path',
      ]).timeout(timeout + const Duration(seconds: 1));
      if (r.exitCode != 0) {
        return null;
      }
      final body = (r.stdout as String?)?.trim() ?? '';
      if (body.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return null;
      }
      final raw = decoded['appVersion']?.toString() ??
          decoded['app_version']?.toString();
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final version = parseCameraAppVersionDisplay(raw);
      return version == kUnavailableDisplay ? null : raw.trim();
    } catch (e) {
      debugPrint('camera-deviceinfo: wget fallback failed: $e');
      return null;
    }
  }

  void dispose() {
    _http.close(force: true);
  }
}
