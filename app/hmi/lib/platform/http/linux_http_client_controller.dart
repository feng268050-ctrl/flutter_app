import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

class LinuxHttpClientController implements HttpClientController {
  LinuxHttpClientController({this.proxyPath = HttpProxyStore.defaultPath});

  final String proxyPath;

  @override
  Future<HttpProxyConfig> getProxy() async {
    try {
      final f = File(proxyPath);
      if (!await f.exists()) {
        return HttpProxyConfig.disabled;
      }
      return HttpProxyStore.parse(await f.readAsString());
    } catch (_) {
      return HttpProxyConfig.disabled;
    }
  }

  @override
  Future<void> setProxy(HttpProxyConfig config) async {
    final f = File(proxyPath);
    await f.parent.create(recursive: true);
    await f.writeAsString(HttpProxyStore.serialize(config), flush: true);
    lwsTrace('http: proxy saved ${config.toString()}');
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
      client = HttpClient();
      client.connectionTimeout = timeout;
      client.idleTimeout = timeout;
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
        client.findProxy = (_) => HttpClient.findProxyFromEnvironment(url);
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
      // Optional curl fallback when Dart TLS/proxy is awkward on-device.
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
      return HttpProbeResult(
        ok: false,
        error: e.toString(),
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
    if (proxy.enabled && proxy.host.isNotEmpty) {
      final auth = proxy.username.isNotEmpty
          ? '${proxy.username}:${proxy.password}@'
          : '';
      args.addAll(['-x', 'http://$auth${proxy.host}:${proxy.port}']);
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
