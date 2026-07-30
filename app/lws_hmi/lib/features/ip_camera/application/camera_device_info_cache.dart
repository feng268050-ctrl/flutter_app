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

  String get currentOrDash => _cached ?? kUnavailableDisplay;

  /// Drop cached success so the next [fetch] hits the network.
  void invalidate() {
    _cached = null;
    _cachedHost = null;
  }

  Future<String> fetch(String cameraHost) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      _cached = null;
      _cachedHost = null;
      return kUnavailableDisplay;
    }
    if (_cachedHost == host &&
        _cached != null &&
        _cached!.isNotEmpty &&
        _cached != kUnavailableDisplay) {
      return _cached!;
    }
    final existing = _inFlight;
    if (existing != null && _cachedHost == host) {
      return existing;
    }
    final done = _fetchOnce(host);
    _inFlight = done;
    try {
      return await done;
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
        final viaWget = await _wgetFallback(host);
        if (viaWget != null) {
          _cached = viaWget;
          _cachedHost = host;
          debugPrint('camera-deviceinfo: ok via wget → $viaWget');
          return viaWget;
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
      if (version == kUnavailableDisplay) {
        return kUnavailableDisplay;
      }
      _cached = version;
      _cachedHost = host;
      debugPrint('camera-deviceinfo: ok → $version');
      return version;
    } catch (e, st) {
      debugPrint('camera-deviceinfo: $e\n$st');
      try {
        final viaWget = await _wgetFallback(host);
        if (viaWget != null) {
          _cached = viaWget;
          _cachedHost = host;
          debugPrint('camera-deviceinfo: ok via wget → $viaWget');
          return viaWget;
        }
      } catch (_) {}
      return kUnavailableDisplay;
    }
  }

  /// BusyBox wget backup when Dart [HttpClient] auth headers misbehave.
  Future<String?> _wgetFallback(String host) async {
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
      final version = parseCameraAppVersionDisplay(raw);
      return version == kUnavailableDisplay ? null : version;
    } catch (e) {
      debugPrint('camera-deviceinfo: wget fallback failed: $e');
      return null;
    }
  }

  void dispose() {
    _http.close(force: true);
  }
}
