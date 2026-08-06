import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/cloud_headers.dart';
import 'package:lws_hmi/platform/cloud/device_api_origin_config.dart';

void main() {
  group('CloudHeaders device Bearer', () {
    test('forRequest omits Authorization without token', () {
      final h = CloudHeaders.forRequest(appVersion: '1.0.0');
      expect(h['App-Version'], '1.0.0');
      expect(h['Device-Type'], 'Linux');
      expect(h.containsKey('Authorization'), isFalse);
    });

    test('forRequest attaches Bearer when token present', () {
      final h = CloudHeaders.forRequest(
        appVersion: '1.0.0',
        accessToken: 'tok.abc',
      );
      expect(h['Authorization'], 'Bearer tok.abc');
    });

    test('isDeviceAuthBootstrapPath detects activate and token', () {
      expect(
        CloudHeaders.isDeviceAuthBootstrapPath(
          Uri.parse('https://api.example/v1/devices/sn/activate'),
        ),
        isTrue,
      );
      expect(
        CloudHeaders.isDeviceAuthBootstrapPath(
          Uri.parse('https://api.example/v1/devices/sn/token'),
        ),
        isTrue,
      );
      expect(
        CloudHeaders.isDeviceAuthBootstrapPath(
          Uri.parse('https://api.example/v1/devices/sn/users'),
        ),
        isFalse,
      );
      expect(
        CloudHeaders.isDeviceAuthBootstrapPath(
          Uri.parse('https://api.example/ws/device?sn=x'),
        ),
        isFalse,
      );
    });
  });

  group('DeviceApiOriginConfig WS path', () {
    test('deviceWebSocketUri stays on /ws/device with sn query', () {
      final uri = DeviceApiOriginConfig.deviceWebSocketUri(
        pinnedHttpBase: Uri.parse('https://api-test.example'),
        deviceSn: 'abc123',
      );
      expect(uri.scheme, 'wss');
      expect(uri.path, '/ws/device');
      expect(uri.queryParameters['sn'], 'abc123');
    });
  });
}
