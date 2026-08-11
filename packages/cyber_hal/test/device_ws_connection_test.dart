import 'package:cyber_hal/network/cloud_http_client.dart';
import 'package:cyber_hal/network/device_ws_connection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceWsConnectionManager lifecycle', () {
    late DeviceWsConnectionManager ws;

    setUp(() {
      ws = DeviceWsConnectionManager(
        cloudHttp: CloudHttpClient(appVersion: 'test'),
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
      await ws.connect(Uri.parse('wss://example.test/ws/device?sn=X'));
      expect(ws.url, isNotNull);
      expect(ws.state, DeviceWsState.disconnected);
      await ws.reconnectIfIdle();
      expect(ws.state, DeviceWsState.disconnected);
      expect(ws.forcedDisconnectSuppressed, isTrue);
    });
  });
}
