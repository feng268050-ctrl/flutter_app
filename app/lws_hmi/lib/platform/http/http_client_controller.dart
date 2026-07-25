import 'package:lws_hmi/platform/http/http_proxy_config.dart';

/// Outbound HTTP(S) + proxy for Demo probe and later product APIs.
abstract class HttpClientController {
  Future<HttpProxyConfig> getProxy();

  Future<void> setProxy(HttpProxyConfig config);

  Future<HttpProbeResult> request({
    required String method,
    required Uri url,
    int maxBodyBytes = 2048,
    Duration timeout = const Duration(seconds: 15),
  });

  Future<void> dispose();
}
