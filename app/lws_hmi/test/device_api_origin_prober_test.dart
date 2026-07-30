import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/cloud_environment_tier.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_prober.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';

void main() {
  test('probe pins first success among concurrent candidates (lws-ui race)',
      () async {
    final delays = <String, Duration>{
      'api-test.lasercyber.workers.dev': const Duration(milliseconds: 80),
      'lasercyber.hyurl.com': const Duration(milliseconds: 5),
    };
    final http = _FakeHttp((url) async {
      await Future<void>.delayed(delays[url.host] ?? Duration.zero);
      return const HttpProbeResult(ok: true, statusCode: 200);
    });

    final prober = DeviceApiOriginProber(http: http);
    final pin = await prober.probe(CloudEnvironmentTier.test);
    // Faster hyurl wins — same as lws-ui invokeAny / mobile raceOnce.
    expect(pin?.toString(), 'https://lasercyber.hyurl.com/test');
  });

  test('probe falls back when only secondary is reachable', () async {
    final http = _FakeHttp((url) async {
      if (url.host.contains('workers.dev')) {
        throw TimeoutException('primary down');
      }
      return const HttpProbeResult(ok: true, statusCode: 200);
    });
    final prober = DeviceApiOriginProber(http: http);
    final pin = await prober.probe(CloudEnvironmentTier.test);
    expect(pin?.toString(), 'https://lasercyber.hyurl.com/test');
  });
}

typedef _HttpFn = Future<HttpProbeResult> Function(Uri url);

final class _FakeHttp implements HttpClientController {
  _FakeHttp(this._fn);

  final _HttpFn _fn;

  @override
  Future<HttpProbeResult> request({
    required String method,
    required Uri url,
    int maxBodyBytes = 2048,
    Duration timeout = const Duration(seconds: 15),
  }) =>
      _fn(url);

  @override
  Future<HttpProxyConfig> getProxy() async => HttpProxyConfig.disabled;

  @override
  Future<void> setProxy(HttpProxyConfig config) async {}

  @override
  Future<void> dispose() async {}
}
