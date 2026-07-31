import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/platform/cloud/cloud_headers.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

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

/// Proxy-aware Worker HTTP helpers built on [HttpClientController.getProxy].
final class CloudHttpClient {
  CloudHttpClient({
    required this.http,
    this.appVersion = kSystemVersion,
  });

  final HttpClientController http;
  final String appVersion;

  /// Open a proxy-configured [HttpClient] for cloud HTTP or WebSocket.
  Future<HttpClient> openClient({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final proxy = await http.getProxy();
    final client = HttpClient();
    client.connectionTimeout = timeout;
    client.idleTimeout = timeout;
    _applyProxy(client, proxy);
    return client;
  }

  static void _applyProxy(HttpClient client, HttpProxyConfig proxy) {
    if (proxy.enabled && proxy.host.isNotEmpty) {
      client.findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
      if (proxy.username.isNotEmpty) {
        client.addProxyCredentials(
          proxy.host,
          proxy.port,
          'proxy',
          HttpClientBasicCredentials(proxy.username, proxy.password),
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
  }) async {
    HttpClient? client;
    try {
      client = await openClient(timeout: timeout);
      final req = await client.openUrl(method.toUpperCase(), url).timeout(timeout);
      final merged = {
        ...CloudHeaders.forRequest(appVersion: appVersion),
        ...?headers,
      };
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

  Future<CloudHttpResponse> getJson(Uri url, {Duration? timeout}) =>
      request(method: 'GET', url: url, timeout: timeout ?? const Duration(seconds: 15));

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
