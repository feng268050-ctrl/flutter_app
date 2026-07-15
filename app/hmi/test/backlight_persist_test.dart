import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/backlight/linux_sysfs_backlight.dart';

void main() {
  test('setBrightnessPercent persists preference file', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-bl-');
    addTearDown(() => tmp.delete(recursive: true));

    final classDir = Directory('${tmp.path}/class');
    final device = Directory('${classDir.path}/backlight');
    await device.create(recursive: true);
    await File('${device.path}/max_brightness').writeAsString('100\n');
    await File('${device.path}/brightness').writeAsString('50\n');

    final pref = File('${tmp.path}/backlight-brightness');
    final bl = LinuxSysfsBacklight(
      classDir: classDir.path,
      preferencePath: pref.path,
    );

    await bl.setBrightnessPercent(40);
    expect(await pref.exists(), isTrue);
    expect((await pref.readAsString()).trim(), '40');

    await File('${device.path}/brightness').writeAsString('10\n');
    await bl.applyPersistedPreference();
    expect((await File('${device.path}/brightness').readAsString()).trim(), '40');
  });
}
