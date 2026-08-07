import 'dart:io';

import 'package:cyber_hal/output/load_profile.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/linux_load_profile.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LoadProfileMode.parse', () {
    expect(LoadProfileMode.parse('balanced'), LoadProfileMode.balanced);
    expect(LoadProfileMode.parse('performance'), LoadProfileMode.performance);
    expect(LoadProfileMode.parse(null), LoadProfileMode.performance);
    expect(LoadProfileMode.parse('nonsense'), LoadProfileMode.performance);
  });

  test('OutputPrefs.powerConf defaults under /var/lib/hal', () {
    expect(OutputPrefs.powerConf, '/var/lib/hal/power.conf');
    expect(OutputPrefs.keyPowerMode, 'mode');
  });

  test('StubLoadProfile round-trip', () async {
    final p = StubLoadProfile();
    expect(await p.getMode(), LoadProfileMode.performance);
    await p.setMode(LoadProfileMode.balanced);
    expect(await p.getMode(), LoadProfileMode.balanced);
    await p.setMode(LoadProfileMode.performance);
    expect(await p.getMode(), LoadProfileMode.performance);
  });

  test('LinuxLoadProfile defaults to performance when conf missing', () async {
    final dir = await Directory.systemTemp.createTemp('load-profile-missing-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/power.conf');

    final lp = LinuxLoadProfile(
      preferencePath: pref.path,
      setPowerModeCommand: const [],
    );
    expect(await lp.getMode(), LoadProfileMode.performance);
  });

  test('LinuxLoadProfile warm-reads mode from power.conf', () async {
    final dir = await Directory.systemTemp.createTemp('load-profile-read-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/power.conf');
    await pref.writeAsString('mode=balanced\n');

    final lp = LinuxLoadProfile(
      preferencePath: pref.path,
      setPowerModeCommand: const [],
    );
    expect(await lp.getMode(), LoadProfileMode.balanced);
  });

  test('LinuxLoadProfile setMode via fake helper', () async {
    final dir = await Directory.systemTemp.createTemp('load-profile-set-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/power.conf');

    final lp = LinuxLoadProfile(
      preferencePath: pref.path,
      setPowerModeCommand: const <String>['set-power-mode'],
      runHelper: (exe, args) async {
        expect(exe, 'set-power-mode');
        expect(args, ['balanced']);
        await upsertKeyValueConfFile(pref.path, {
          OutputPrefs.keyPowerMode: args.last,
        });
        return 0;
      },
    );

    await lp.setMode(LoadProfileMode.balanced);
    expect(await lp.getMode(), LoadProfileMode.balanced);

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyPowerMode], 'balanced');
  });

  test('LinuxLoadProfile invalid mode falls back to performance', () async {
    final dir = await Directory.systemTemp.createTemp('load-profile-bad-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/power.conf');
    await pref.writeAsString('mode=powersave\n');

    final lp = LinuxLoadProfile(
      preferencePath: pref.path,
      setPowerModeCommand: const [],
    );
    expect(await lp.getMode(), LoadProfileMode.performance);
  });
}
