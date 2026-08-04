import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_show_time_request.dart';

void main() {
  group('CameraShowTimeRequest', () {
    test('create with fillNow uses local wall-clock fields', () {
      final req = CameraShowTimeRequest.create(
        enable: 1,
        positionX: 10,
        positionY: 20,
        fillNow: true,
        now: DateTime(2026, 8, 4, 20, 22, 33),
      );
      expect(req.enable, 1);
      expect(req.positionx, 10);
      expect(req.positiony, 20);
      expect(req.year, 2026);
      expect(req.month, 8);
      expect(req.day, 4);
      expect(req.hour, 20);
      expect(req.minute, 22);
      expect(req.sec, 33);
      expect(req.toJson()['mon'], 8);
      expect(req.toJson()['min'], 22);
    });

    test('create without fillNow fills zeros', () {
      final req = CameraShowTimeRequest.create(
        enable: 0,
        positionX: 5,
        positionY: 6,
        fillNow: false,
      );
      expect(req.year, 0);
      expect(req.month, 0);
      expect(req.day, 0);
      expect(req.hour, 0);
      expect(req.minute, 0);
      expect(req.sec, 0);
    });
  });
}
