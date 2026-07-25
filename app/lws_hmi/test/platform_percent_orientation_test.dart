import 'dart:io';

import 'package:cyber_hal/output/display/orientation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/backlight/linux_sysfs_backlight.dart';
import 'package:lws_hmi/platform/percent.dart';

void main() {
  group('clampPercent', () {
    test('clamps above and below range', () {
      expect(clampPercent(150), 100);
      expect(clampPercent(-10), 0);
      expect(clampPercent(40), 40);
    });
  });

  group('percent device mapping', () {
    test('round-trips mid values on 0..255', () {
      expect(percentToDevice(0, 255), 0);
      expect(percentToDevice(100, 255), 255);
      expect(deviceToPercent(0, 255), 0);
      expect(deviceToPercent(255, 255), 100);
      expect(deviceToPercent(percentToDevice(50, 255), 255), 50);
    });

    test('handles max <= 0', () {
      expect(percentToDevice(50, 0), 0);
      expect(deviceToPercent(10, 0), 0);
    });
  });

  group('OrientationMode', () {
    test('default / unknown token is landscape', () {
      expect(OrientationMode.parse(null), OrientationMode.landscape);
      expect(OrientationMode.parse(''), OrientationMode.landscape);
      expect(OrientationMode.parse('nonsense'), OrientationMode.landscape);
    });

    test('parses portrait case-insensitively', () {
      expect(OrientationMode.parse('portrait\n'), OrientationMode.portrait);
      expect(OrientationMode.parse('PORTRAIT'), OrientationMode.portrait);
    });

    test('wire tokens are stable', () {
      expect(OrientationMode.landscape.wireName, 'landscape');
      expect(OrientationMode.portrait.wireName, 'portrait');
    });
  });

  group('LinuxSysfsBacklight preference', () {
    test('prefers backlight over led-red-pwm', () async {
      final root = await Directory.systemTemp.createTemp('bl-');
      addTearDown(() => root.delete(recursive: true));

      final led = Directory('${root.path}/led-red-pwm');
      await led.create();
      await File('${led.path}/brightness').writeAsString('50');
      await File('${led.path}/max_brightness').writeAsString('100');

      final panel = Directory('${root.path}/backlight');
      await panel.create();
      await File('${panel.path}/brightness').writeAsString('80');
      await File('${panel.path}/max_brightness').writeAsString('255');

      final ctl = LinuxSysfsBacklight(classDir: root.path);
      expect(await ctl.ensureDevice(), isTrue);
      expect(ctl.brightnessPath, '${panel.path}/brightness');
      expect(ctl.maxBrightness, 255);
    });
  });
}
