import 'dart:io';

import 'package:cyber_hal/output/display/orientation.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/display/linux_orientation.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OrientationMode.parse', () {
    expect(OrientationMode.parse('portrait'), OrientationMode.portrait);
    expect(OrientationMode.parse('landscape'), OrientationMode.landscape);
    expect(OrientationMode.parse(null), OrientationMode.landscape);
    expect(OrientationMode.parse('nonsense'), OrientationMode.landscape);
  });

  test('OutputPrefs defaults under /var/lib/hal', () {
    expect(OutputPrefs.displayConf, '/var/lib/hal/display.conf');
    expect(OutputPrefs.soundConf, '/var/lib/hal/sound.conf');
    expect(OutputPrefs.keyOrientation, 'orientation');
  });

  test('StubOrientation round-trip', () async {
    final o = StubOrientation();
    expect(await o.getPreferred(), OrientationMode.landscape);
    await o.setPreferred(OrientationMode.portrait);
    expect(await o.getPreferred(), OrientationMode.portrait);
  });

  test('LinuxOrientation warm-reads orientation from display.conf', () async {
    final dir = await Directory.systemTemp.createTemp('orientation-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/display.conf');
    await pref.writeAsString('backlight=40\norientation=portrait\n');

    final o = LinuxOrientation(
      preferencePath: pref.path,
      changeOrientationCommand: const [],
      restartCommand: const [],
    );
    expect(await o.getPreferred(), OrientationMode.portrait);
  });

  test('LinuxOrientation setPreferred via fake helper writes conf', () async {
    final dir = await Directory.systemTemp.createTemp('orientation-set-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/display.conf');
    await pref.writeAsString('backlight=40\n');

    final o = LinuxOrientation(
      preferencePath: pref.path,
      changeOrientationCommand: const <String>['change-orientation'],
      restartCommand: const [],
      runHelper: (exe, args) async {
        expect(exe, 'change-orientation');
        expect(args, ['portrait']);
        await upsertKeyValueConfFile(pref.path, {
          OutputPrefs.keyOrientation: args.last,
        });
        return 0;
      },
    );

    await o.setPreferred(OrientationMode.portrait, apply: false);
    expect(await o.getPreferred(), OrientationMode.portrait);

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyOrientation], 'portrait');
    expect(map[OutputPrefs.keyBacklight], '40');
  });

  test('LinuxOrientation imports legacy display-orientation file', () async {
    final dir = await Directory.systemTemp.createTemp('orientation-legacy-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/display.conf');
    final legacy = File('${dir.path}/display-orientation');
    await legacy.writeAsString('portrait\n');

    final o = LinuxOrientation(
      preferencePath: pref.path,
      legacyPreferencePaths: [legacy.path],
      changeOrientationCommand: const [],
      restartCommand: const [],
    );
    expect(await o.getPreferred(), OrientationMode.portrait);
    expect(await legacy.exists(), isFalse);

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyOrientation], 'portrait');
  });
}
