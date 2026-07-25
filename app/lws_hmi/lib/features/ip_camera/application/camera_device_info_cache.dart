import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/device/display_value.dart';

/// Cached camera software version from HTTP `GET …/System/deviceinfo`.
///
/// Bounded, non-SETUP GET (not a connectivity probe). Returns
/// [kUnavailableDisplay] when unavailable.
final class CameraDeviceInfoCache {
  CameraDeviceInfoCache({
    this.port = 9000,
    this.path = '/System/deviceinfo',
    this.timeout = const Duration(seconds: 3),
    HttpClient? httpClient,
  }) : _http = httpClient ?? HttpClient();

  final int port;
  final String path;
  final Duration timeout;
  final HttpClient _http;

  String? _cached;
  String? _cachedHost;
  Future<String>? _inFlight;

  String get currentOrDash => _cached ?? kUnavailableDisplay;

  Future<String> fetch(String cameraHost) async {
    final host = cameraHost.trim();
    if (host.isEmpty) {
      _cached = null;
      _cachedHost = null;
      return kUnavailableDisplay;
    }
    if (_cachedHost == host && _cached != null && _cached!.isNotEmpty) {
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
      final req = await _http.getUrl(uri).timeout(timeout);
      final res = await req.close().timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return kUnavailableDisplay;
      }
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        return kUnavailableDisplay;
      }
      final version = decoded['appVersion']?.toString().trim() ??
          decoded['app_version']?.toString().trim() ??
          '';
      if (version.isEmpty) {
        return kUnavailableDisplay;
      }
      _cached = version;
      _cachedHost = host;
      return version;
    } catch (e, st) {
      debugPrint('camera-deviceinfo: $e\n$st');
      return kUnavailableDisplay;
    }
  }

  void dispose() {
    _http.close(force: true);
  }
}
