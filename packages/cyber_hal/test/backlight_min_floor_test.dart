import 'dart:io';

import 'package:cyber_hal/output/display/backlight.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/linux/percent.dart';
import 'package:cyber_hal/src/output/display/linux_sysfs_backlight.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/stub/stub_backlight.dart';
import 'package:cyber_hal/src/stub/stub_volume.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('logical clamp still allows zero', () {
    expect(clampPercent(0), 0);
    expect(clampPercent(-5), 0);
    expect(clampPercent(120), 100);
  });

  test('backlightPercentToDevice maps 0 to hardware floor', () {
    expect(kBacklightHwFloorPercent, 5);
    expect(backlightPercentToDevice(0, 100), 5);
    expect(backlightPercentToDevice(0, 255), greaterThanOrEqualTo(1));
    expect(backlightPercentToDevice(100, 255), 255);
    expect(backlightPercentToDevice(0, 255), isNot(0));
  });

  test('backlightDeviceToPercent reverse-maps floor to logical 0', () {
    final floor = backlightHwFloorDevice(100);
    expect(backlightDeviceToPercent(floor, 100), 0);
    expect(backlightDeviceToPercent(100, 100), 100);
    expect(backlightDeviceToPercent(0, 100), 0);
  });

  test('StubBacklight allows logical zero', () async {
    final bl = StubBacklight(initialPercent: 40);
    await bl.setBrightnessPercent(0);
    expect(await bl.getBrightnessPercent(), 0);
    await bl.setBrightnessPercent(120);
    expect(await bl.getBrightnessPercent(), 100);
  });

  test('StubVolume still allows zero', () async {
    final vol = StubVolume(initialPercent: 10);
    await vol.setVolumePercent(0);
    expect(await vol.getVolumePercent(), 0);
  });

  test('LinuxSysfsBacklight set 0 persists logical 0 with non-zero sysfs', () async {
    final tmp = await Directory.systemTemp.createTemp('hal-bl-floor-');
    addTearDown(() => tmp.delete(recursive: true));

    final classDir = Directory('${tmp.path}/class');
    final device = Directory('${classDir.path}/backlight');
    await device.create(recursive: true);
    await File('${device.path}/max_brightness').writeAsString('100\n');
    await File('${device.path}/brightness').writeAsString('50\n');

    final pref = File('${tmp.path}/display.conf');
    final bl = LinuxSysfsBacklight(
      classDir: classDir.path,
      preferencePath: pref.path,
      changeBacklightCommand: const <String>[],
    );

    await bl.setBrightnessPercent(0);
    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyBacklight], '0');
    final raw =
        int.parse((await File('${device.path}/brightness').readAsString()).trim());
    expect(raw, backlightHwFloorDevice(100));
    expect(raw, greaterThanOrEqualTo(1));
    expect(await bl.getBrightnessPercent(), 0);
  });

  test('LinuxSysfsBacklight restores logical 0 to hardware floor', () async {
    final tmp = await Directory.systemTemp.createTemp('hal-bl-legacy-');
    addTearDown(() => tmp.delete(recursive: true));

    final classDir = Directory('${tmp.path}/class');
    final device = Directory('${classDir.path}/backlight');
    await device.create(recursive: true);
    await File('${device.path}/max_brightness').writeAsString('100\n');
    await File('${device.path}/brightness').writeAsString('50\n');

    final pref = File('${tmp.path}/display.conf');
    await pref.writeAsString('backlight=0\n');

    final bl = LinuxSysfsBacklight(
      classDir: classDir.path,
      preferencePath: pref.path,
      changeBacklightCommand: const <String>[],
    );

    await bl.applyPersistedPreference();
    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyBacklight], '0');
    final raw =
        int.parse((await File('${device.path}/brightness').readAsString()).trim());
    expect(raw, backlightHwFloorDevice(100));
  });
}
