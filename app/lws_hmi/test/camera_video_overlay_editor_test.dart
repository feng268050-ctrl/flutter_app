import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_video_overlay_editor.dart';

void main() {
  Map<String, Object?> overlayRoot() => <String, Object?>{
        'VideoOverlay': <String, Object?>{
          'NameOverlay': <String, Object?>{},
        },
      };

  group('CameraVideoOverlayEditor', () {
    test('applyNameOverlay enable=1 sets position and name', () {
      final updated = CameraVideoOverlayEditor.applyNameOverlay(
        overlayRoot(),
        enable: 1,
        positionX: 20,
        positionY: 30,
        name: 'Laser-01',
      );
      expect(updated, isNotNull);
      final nameOverlay = (updated!['VideoOverlay'] as Map)['NameOverlay'] as Map;
      expect(nameOverlay['enable'], 1);
      expect(nameOverlay['x'], 20);
      expect(nameOverlay['y'], 80);
      expect(nameOverlay['name'], 'Laser-01');
    });

    test('applyNameOverlay enable=0 hides name', () {
      final updated = CameraVideoOverlayEditor.applyNameOverlay(
        overlayRoot(),
        enable: 0,
        positionX: 10,
        positionY: 10,
        name: 'HGDevice',
      );
      expect(updated, isNotNull);
      final nameOverlay = (updated!['VideoOverlay'] as Map)['NameOverlay'] as Map;
      expect(nameOverlay['enable'], 0);
    });

    test('parseOverlayConfig rejects errCode wrapper', () {
      expect(
        CameraVideoOverlayEditor.parseOverlayConfig({'errCode': 400}),
        isNull,
      );
    });

    test('parseOverlayConfig accepts VideoOverlay root', () {
      expect(
        CameraVideoOverlayEditor.parseOverlayConfig(overlayRoot()),
        isNotNull,
      );
    });
  });
}
