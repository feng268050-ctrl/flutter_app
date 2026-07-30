import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';
import 'package:lws_hmi/platform/http/http_client_controller.dart';
import 'package:lws_hmi/platform/http/http_proxy_config.dart';

final class _FakeHttp implements HttpClientController {
  @override
  Future<HttpProxyConfig> getProxy() async => HttpProxyConfig.disabled;

  @override
  Future<void> setProxy(HttpProxyConfig config) async {}

  @override
  Future<HttpProbeResult> request({
    required String method,
    required Uri url,
    int maxBodyBytes = 2048,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return const HttpProbeResult(ok: true, statusCode: 200);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('DeviceWsConnectionManager lifecycle', () {
    late DeviceWsConnectionManager ws;

    setUp(() {
      ws = DeviceWsConnectionManager(
        cloudHttp: CloudHttpClient(http: _FakeHttp()),
      );
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('default ping interval matches lws-ui 30s', () {
      expect(
        DeviceWsConnectionManager.defaultPingInterval,
        const Duration(seconds: 30),
      );
      expect(ws.pingInterval, DeviceWsConnectionManager.defaultPingInterval);
    });

    test('reconnectIfIdle is a no-op without URL', () async {
      await ws.reconnectIfIdle();
      expect(ws.state, DeviceWsState.disconnected);
    });

    test('forced disconnect suppresses reconnectIfIdle', () async {
      await ws.disconnect(forced: true);
      expect(ws.forcedDisconnectSuppressed, isTrue);
      // Seeds URL without opening (forced latch skips _open).
      await ws.connect(Uri.parse('wss://example.test/ws/device?sn=X'));
      expect(ws.url, isNotNull);
      expect(ws.state, DeviceWsState.disconnected);
      await ws.reconnectIfIdle();
      expect(ws.state, DeviceWsState.disconnected);
      expect(ws.forcedDisconnectSuppressed, isTrue);
    });
  });
}
