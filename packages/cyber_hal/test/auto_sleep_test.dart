import 'dart:io';

import 'package:cyber_hal/output/display/auto_sleep.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/display/linux_auto_sleep.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AutoSleepPolicy.parse', () {
    expect(AutoSleepPolicy.parse('10'), AutoSleepPolicy.minutes10);
    expect(AutoSleepPolicy.parse('never'), AutoSleepPolicy.never);
  });

  test('LinuxAutoSleep persists auto_sleep in display.conf', () async {
    final dir = await Directory.systemTemp.createTemp('auto-sleep-');
    addTearDown(() => dir.delete(recursive: true));
    final pref = File('${dir.path}/display.conf');
    // Pre-seed backlight key to ensure upsert preserves siblings.
    await pref.writeAsString('backlight=40\n');

    final sleep = LinuxAutoSleep(preferencePath: pref.path);
    await sleep.setPolicy(AutoSleepPolicy.minutes30);
    expect(await sleep.getPolicy(), AutoSleepPolicy.minutes30);

    final map = parseKeyValueConf(await pref.readAsString());
    expect(map[OutputPrefs.keyAutoSleep], '30');
    expect(map[OutputPrefs.keyBacklight], '40');

    final again = LinuxAutoSleep(preferencePath: pref.path);
    expect(await again.getPolicy(), AutoSleepPolicy.minutes30);
  });

  test('StubAutoSleep blanks absolute 0; double-tap wakes', () async {
    final bl = StubBacklight(initialPercent: 55);
    final sleep = StubAutoSleep(
      doubleTapWindow: const Duration(milliseconds: 500),
    );
    sleep.arm(backlight: bl);
    await sleep.forceBlankForTest();
    expect(sleep.isBlanked, isTrue);
    expect(bl.absoluteForTest, 0);

    sleep.noteActivity();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sleep.isBlanked, isTrue);

    sleep.noteActivity();
    sleep.noteActivity();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(sleep.isBlanked, isFalse);
    expect(await bl.getBrightnessPercent(), 55);
  });
}
