import 'dart:io';

import 'package:cyber_hal/output/backlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/backlight/linux_sysfs_backlight.dart';
import 'package:lws_hmi/platform/percent.dart';

void main() {
  test('setBrightnessPercent persists via change-backlight helper', () async {
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
      changeBacklightCommand: const <String>['change-backlight'],
      runHelper: (exe, args) async {
        expect(exe, 'change-backlight');
        expect(args, ['40']);
        final pct = clampPercent(int.parse(args.single));
        final val = backlightPercentToDevice(pct, 100);
        await File('${device.path}/brightness').writeAsString('$val\n');
        await pref.writeAsString('$pct\n');
        return 0;
      },
    );

    await bl.setBrightnessPercent(40);
    expect(await pref.exists(), isTrue);
    expect((await pref.readAsString()).trim(), '40');

    await File('${device.path}/brightness').writeAsString('10\n');
    await bl.applyPersistedPreference();
    expect(
      (await File('${device.path}/brightness').readAsString()).trim(),
      '${backlightPercentToDevice(40, 100)}',
    );
  });

  test('helper path accepts logical zero and remaps hardware', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-bl-floor-');
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
      changeBacklightCommand: const <String>['change-backlight'],
      runHelper: (exe, args) async {
        expect(args, ['0']);
        final pct = clampPercent(int.parse(args.single));
        final val = backlightPercentToDevice(pct, 100);
        await File('${device.path}/brightness').writeAsString('$val\n');
        await pref.writeAsString('$pct\n');
        return 0;
      },
    );

    await bl.setBrightnessPercent(0);
    expect((await pref.readAsString()).trim(), '0');
    expect(
      (await File('${device.path}/brightness').readAsString()).trim(),
      '${backlightHwFloorDevice(100)}',
    );
  });
}
