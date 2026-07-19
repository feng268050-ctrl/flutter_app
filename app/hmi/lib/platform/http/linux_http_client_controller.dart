import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cyber_hal/network.dart';
import 'package:lws_hmi/platform/datetime/date_time_controller.dart';
import 'package:lws_hmi/platform/datetime/linux_date_time_controller.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// System CA path used only for optional curl `--cacert` (not loaded into Dart).
///
/// P2.1 diagnostic: Dart relies on default [SecurityContext] after wall-clock
/// sync — explicit `setTrustedCertificatesBytes` was removed to confirm HTTPS
/// failures were due to stale RTC (not missing CA load).
const String kSystemCaBundlePath = '/etc/ssl/certs/ca-certificates.crt';

class LinuxHttpClientController implements HttpClientController {
  LinuxHttpClientController({
    Proxy? proxy,
    this.caBundlePath = kSystemCaBundlePath,
    DateTimeController? dateTimeController,
  })  : _proxy = proxy ?? LinuxProxy(),
        dateTimeController = dateTimeController ?? LinuxDateTimeController();

  final Proxy _proxy;
  final String caBundlePath;
  final DateTimeController dateTimeController;

  @override
  Future<HttpProxyConfig> getProxy() async {
    try {
      return _fromProxySettings(await _proxy.getSettings());
    } catch (_) {
      return HttpProxyConfig.disabled;
    }
  }

  @override
  Future<void> setProxy(HttpProxyConfig config) async {
    if (config.enabled && config.host.trim().isEmpty) {
      throw ArgumentError('proxy host is empty');
    }
    await _proxy.setSettings(_toProxySettings(config));
    lwsTrace('http: proxy saved ${config.toString()}');
  }

  /// Demo maps a single host:port onto both http and https schemes.
  static ProxySettings _toProxySettings(HttpProxyConfig c) {
    if (!c.enabled || c.host.isEmpty) {
      return const ProxySettings();
    }
    final uri = ProxyUri(
      scheme: ProxyScheme.http,
      host: c.host,
      port: c.port,
      username: c.username.isEmpty ? null : c.username,
      password: c.password.isEmpty ? null : c.password,
    );
    return ProxySettings(
      enabled: true,
      httpProxy: uri,
      httpsProxy: uri,
      noProxy: const ['localhost', '127.0.0.1'],
    );
  }

  static HttpProxyConfig _fromProxySettings(ProxySettings s) {
    final u = s.httpProxy ?? s.httpsProxy ?? s.allProxy;
    if (!s.enabled || u == null || u.host.isEmpty) {
      return HttpProxyConfig.disabled;
    }
    return HttpProxyConfig(
      enabled: true,
      host: u.host,
      port: u.port,
      username: u.username ?? '',
      password: u.password ?? '',
    );
  }

  @override
  Future<HttpProbeResult> request({
    required String method,
    required Uri url,
    int maxBodyBytes = 2048,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final sw = Stopwatch()..start();
    final proxy = await getProxy();
    HttpClient? client;
    try {
      if (url.isScheme('https')) {
        await dateTimeController.ensureSaneForTls();
      }
      // Default SecurityContext only (no setTrustedCertificatesBytes).
      client = HttpClient();
      client.connectionTimeout = timeout;
      client.idleTimeout = timeout;
      // HAL proxy off ⇒ DIRECT. Do not consult process env: systemd may still
      // hold http_proxy after files were cleared (stale manager environment).
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

      final req = await client.openUrl(method.toUpperCase(), url).timeout(timeout);
      req.followRedirects = true;
      final resp = await req.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in resp) {
        if (bytes.length >= maxBodyBytes) {
          break;
        }
        final remain = maxBodyBytes - bytes.length;
        bytes.addAll(chunk.take(remain));
      }
      sw.stop();
      var body = '';
      try {
        body = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        body = '<binary ${bytes.length}B>';
      }
      return HttpProbeResult(
        ok: resp.statusCode >= 200 && resp.statusCode < 400,
        statusCode: resp.statusCode,
        reasonPhrase: resp.reasonPhrase,
        bodySnippet: body,
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      lwsTrace('http: request failed: $e');
      final curl = await _curlFallback(
        method: method,
        url: url,
        proxy: proxy,
        maxBodyBytes: maxBodyBytes,
        timeout: timeout,
      );
      if (curl != null) {
        return curl;
      }
      final clock = DateTime.now().toUtc();
      final hint = clock.year < 2025
          ? ' [clock ${clock.toIso8601String()} UTC looks stale — TLS needs wall clock]'
          : '';
      return HttpProbeResult(
        ok: false,
        error: '$e$hint',
        elapsedMs: sw.elapsedMilliseconds,
      );
    } finally {
      client?.close(force: true);
    }
  }

  Future<HttpProbeResult?> _curlFallback({
    required String method,
    required Uri url,
    required HttpProxyConfig proxy,
    required int maxBodyBytes,
    required Duration timeout,
  }) async {
    if (!await File('/usr/bin/curl').exists() &&
        !await _which('curl')) {
      return null;
    }
    final sw = Stopwatch()..start();
    final args = <String>[
      '-sS',
      '-X',
      method.toUpperCase(),
      '-m',
      '${timeout.inSeconds}',
      '-w',
      '\n__LWS_HTTP_CODE__:%{http_code}',
      '-o',
      '-',
    ];
    if (await File(caBundlePath).exists()) {
      args.addAll(['--cacert', caBundlePath]);
    }
    if (proxy.enabled && proxy.host.isNotEmpty) {
      final auth = proxy.username.isNotEmpty
          ? '${proxy.username}:${proxy.password}@'
          : '';
      args.addAll(['-x', 'http://$auth${proxy.host}:${proxy.port}']);
    } else {
      // curl inherits process env; ignore stale http_proxy when HAL is off.
      args.addAll(['--noproxy', '*']);
    }
    args.add(url.toString());
    try {
      final r = await Process.run('curl', args);
      sw.stop();
      final out = (r.stdout as String? ?? '');
      final codeMatch = RegExp(r'__LWS_HTTP_CODE__:(\d+)').firstMatch(out);
      final code = int.tryParse(codeMatch?.group(1) ?? '');
      var body = out;
      if (codeMatch != null) {
        body = out.substring(0, codeMatch.start).trimRight();
      }
      if (body.length > maxBodyBytes) {
        body = body.substring(0, maxBodyBytes);
      }
      if (r.exitCode != 0 && code == null) {
        return HttpProbeResult(
          ok: false,
          error: (r.stderr as String?)?.trim().isNotEmpty == true
              ? (r.stderr as String).trim()
              : 'curl exit ${r.exitCode}',
          elapsedMs: sw.elapsedMilliseconds,
        );
      }
      return HttpProbeResult(
        ok: code != null && code >= 200 && code < 400,
        statusCode: code,
        bodySnippet: body,
        elapsedMs: sw.elapsedMilliseconds,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _which(String bin) async {
    final r = await Process.run('sh', ['-c', 'command -v $bin']);
    return r.exitCode == 0;
  }

  @override
  Future<void> dispose() async {}
}
