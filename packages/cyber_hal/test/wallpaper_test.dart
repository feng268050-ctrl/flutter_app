import 'dart:io';
import 'dart:typed_data';

import 'package:cyber_hal/output.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/src/output/display/linux_wallpaper.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LinuxWallpaper installs preset next to display.conf', () async {
    final root = await Directory.systemTemp.createTemp('wallpaper-');
    addTearDown(() => root.delete(recursive: true));
    final presets = Directory('${root.path}/presets')..createSync();
    final prefDir = Directory('${root.path}/hal')..createSync();
    final conf = File('${prefDir.path}/display.conf');
    await conf.writeAsString('backlight=80\n');
    final presetFile = File('${presets.path}/home_back.png');
    await presetFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4]));

    final wp = LinuxWallpaper(
      preferencePath: conf.path,
      presetsDirectory: presets.path,
      activePathDefault: '${prefDir.path}/wallpaper.png',
      applyWallpaperCommand: const <String>[],
      restartCommand: const <String>[],
    );

    final listed = await wp.listPresets();
    expect(listed, hasLength(1));
    expect(listed.first.id, 'home_back');

    await wp.setPreset('home_back', apply: false);
    expect(File('${prefDir.path}/wallpaper.png').existsSync(), isTrue);
    final map = parseKeyValueConf(await conf.readAsString());
    expect(map[OutputPrefs.keyWallpaper], '${prefDir.path}/wallpaper.png');
    expect(map[OutputPrefs.keyWallpaperId], 'home_back');
    expect(map[OutputPrefs.keyBacklight], '80');
    expect(wp.activePresetId, 'home_back');
  });

  test('StubWallpaper setPreset updates path', () async {
    final wp = StubWallpaper();
    await wp.setPreset('home_back');
    expect(wp.activePath, '/var/lib/hal/wallpaper.png');
    expect(wp.activePresetId, 'home_back');
  });
}
