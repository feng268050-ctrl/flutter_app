import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/network/cloud_headers.dart';
import 'package:cyber_hal/network/proxy.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/network/linux_proxy.dart';

/// Resolve a cached (or freshly minted) device `access_token`, or null.
typedef DeviceAccessTokenResolver = Future<String?> Function();

/// Force-refresh device `access_token` after HTTP/WS 401; return new token or null.
typedef DeviceAccessTokenRefresher = Future<String?> Function();

/// Result of a full-body cloud HTTP call (not truncated probe).
final class CloudHttpResponse {
  const CloudHttpResponse({
    required this.statusCode,
    required this.body,
    this.error,
  });

  final int statusCode;
  final String body;
  final String? error;

  bool get ok => error == null && statusCode >= 200 && statusCode < 300;
}

/// Proxy-aware Worker HTTP helpers (system [Proxy], injectable [appVersion]).
final class CloudHttpClient {
  CloudHttpClient({
    Proxy? proxy,
    required this.appVersion,
    this.deviceAccessToken,
    this.refreshDeviceAccessToken,
  }) : _proxy = proxy ?? LinuxProxy();

  final Proxy _proxy;
  final String appVersion;

  /// Current device Bearer source (in-memory cache / mint). Optional.
  DeviceAccessTokenResolver? deviceAccessToken;

  /// One-shot remint after gated 401. Optional.
  DeviceAccessTokenRefresher? refreshDeviceAccessToken;

  /// Open a proxy-configured [HttpClient] for cloud HTTP or WebSocket.
  Future<HttpClient> openClient({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final settings = await _proxy.getSettings();
    final client = HttpClient();
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    _applyProxy(client, settings);
    return client;
  }

  /// Headers for Worker HTTP / WS upgrade (App-Version, Device-Type, optional Bearer).
  Future<Map<String, String>> deviceCloudAuthHeaders({
    Uri? url,
    String? accessTokenOverride,
  }) async {
    String? token = accessTokenOverride;
    final bootstrap =
        url != null && CloudHeaders.isDeviceAuthBootstrapPath(url);
    if (!bootstrap && (token == null || token.trim().isEmpty)) {
      final resolver = deviceAccessToken;
      if (resolver != null) {
        token = await resolver();
      }
    }
    return CloudHeaders.forRequest(
      appVersion: appVersion,
      accessToken: bootstrap ? null : token,
    );
  }

  static void _applyProxy(HttpClient client, ProxySettings settings) {
    final u =
        settings.httpProxy ?? settings.httpsProxy ?? settings.allProxy;
    if (settings.enabled && u != null && u.host.isNotEmpty) {
      client.findProxy = (_) => 'PROXY ${u.host}:${u.port}';
      if (u.username != null && u.username!.isNotEmpty) {
        client.addProxyCredentials(
          u.host,
          u.port,
          'proxy',
          HttpClientBasicCredentials(u.username!, u.password ?? ''),
        );
      }
    } else {
      client.findProxy = (_) => 'DIRECT';
    }
  }

  Future<CloudHttpResponse> request({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    List<int>? bodyBytes,
    String? bodyText,
    Duration timeout = const Duration(seconds: 15),
    int maxBodyBytes = 2 * 1024 * 1024,
    bool allowAuthRetry = true,
  }) async {
    final first = await _requestOnce(
      method: method,
      url: url,
      headers: headers,
      bodyBytes: bodyBytes,
      bodyText: bodyText,
      timeout: timeout,
      maxBodyBytes: maxBodyBytes,
    );
    if (!allowAuthRetry ||
        first.statusCode != 401 ||
        CloudHeaders.isDeviceAuthBootstrapPath(url)) {
      return first;
    }
    final refresher = refreshDeviceAccessToken;
    if (refresher == null) {
      return first;
    }
    final refreshed = await refresher();
    if (refreshed == null || refreshed.trim().isEmpty) {
      return first;
    }
    lwsTrace('cloud-http: 401 → reminted token, retrying $method $url');
    return _requestOnce(
      method: method,
      url: url,
      headers: {
        ...?headers,
        ...CloudHeaders.deviceBearer(refreshed),
      },
      bodyBytes: bodyBytes,
      bodyText: bodyText,
      timeout: timeout,
      maxBodyBytes: maxBodyBytes,
      accessTokenOverride: refreshed,
    );
  }

  Future<CloudHttpResponse> _requestOnce({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    List<int>? bodyBytes,
    String? bodyText,
    required Duration timeout,
    required int maxBodyBytes,
    String? accessTokenOverride,
  }) async {
    HttpClient? client;
    try {
      client = await openClient(timeout: timeout);
      final req =
          await client.openUrl(method.toUpperCase(), url).timeout(timeout);
      final auth = await deviceCloudAuthHeaders(
        url: url,
        accessTokenOverride: accessTokenOverride,
      );
      final merged = {
        ...auth,
        ...?headers,
      };
      // Explicit Authorization in [headers] wins (e.g. retry after remint).
      merged.forEach(req.headers.set);
      if (bodyBytes != null) {
        req.contentLength = bodyBytes.length;
        req.add(bodyBytes);
      } else if (bodyText != null) {
        final encoded = utf8.encode(bodyText);
        req.contentLength = encoded.length;
        req.add(encoded);
      }
      final resp = await req.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in resp) {
        if (bytes.length >= maxBodyBytes) {
          break;
        }
        final remain = maxBodyBytes - bytes.length;
        bytes.addAll(chunk.take(remain));
      }
      return CloudHttpResponse(
        statusCode: resp.statusCode,
        body: utf8.decode(bytes, allowMalformed: true),
      );
    } catch (e) {
      lwsTrace('cloud-http: $method $url failed: $e');
      return CloudHttpResponse(
        statusCode: 0,
        body: '',
        error: e.toString(),
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<CloudHttpResponse> getJson(Uri url, {Duration? timeout}) => request(
        method: 'GET',
        url: url,
        timeout: timeout ?? const Duration(seconds: 15),
      );

  Future<CloudHttpResponse> postJson(
    Uri url, {
    Object? jsonBody,
    Duration? timeout,
  }) {
    final text = jsonBody == null ? null : jsonEncode(jsonBody);
    return request(
      method: 'POST',
      url: url,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      bodyText: text,
      timeout: timeout ?? const Duration(seconds: 15),
    );
  }
}
