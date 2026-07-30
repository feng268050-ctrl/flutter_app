import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';

void main() {
  group('parseCameraAppVersionDisplay', () {
    test('strips v prefix and build suffix', () {
      expect(
        parseCameraAppVersionDisplay('v1.0.5 build20251127'),
        '1.0.5',
      );
      expect(
        parseCameraAppVersionDisplay('V1.0.5 BUILD20251127'),
        '1.0.5',
      );
    });

    test('null or blank becomes dash', () {
      expect(parseCameraAppVersionDisplay(null), kUnavailableDisplay);
      expect(parseCameraAppVersionDisplay(''), kUnavailableDisplay);
      expect(parseCameraAppVersionDisplay('   '), kUnavailableDisplay);
    });

    test('plain version passthrough', () {
      expect(parseCameraAppVersionDisplay('2.1.0'), '2.1.0');
    });
  });

  group('cameraHttpBasicAuthorization', () {
    test('matches lws-ui admin:admin Basic header', () {
      // echo -n 'admin:admin' | base64 → YWRtaW46YWRtaW4=
      expect(
        cameraHttpBasicAuthorization(),
        'Basic YWRtaW46YWRtaW4=',
      );
    });
  });
}
