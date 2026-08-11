import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/cloud_http_client.dart';
import 'package:lws_hmi/platform/cloud/device_ws_connection_manager.dart';

void main() {
  group('DeviceWsConnectionManager lifecycle (HMI re-export)', () {
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
    });

    test('forced disconnect suppresses reconnectIfIdle', () async {
      await ws.disconnect(forced: true);
      expect(ws.forcedDisconnectSuppressed, isTrue);
      await ws.connect(Uri.parse('wss://example.test/ws/device?sn=X'));
      await ws.reconnectIfIdle();
      expect(ws.state, DeviceWsState.disconnected);
    });
  });
}
