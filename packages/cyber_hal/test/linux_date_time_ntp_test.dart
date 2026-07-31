import 'dart:io';

import 'package:cyber_hal/src/time/linux_date_time_controller.dart';
import 'package:cyber_hal/src/time/time_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late String confPath;
  late List<List<String>> calls;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hal-datetime-ntp-');
    confPath = '${tmp.path}/datetime.conf';
    calls = <List<String>>[];
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  LinuxDateTimeController controller() {
    return LinuxDateTimeController(
      preferencePath: confPath,
      legacySyncModePath: '${tmp.path}/missing-sync',
      legacyTimezonePath: '${tmp.path}/missing-tz',
      runProcess: (exe, args) async {
        calls.add(<String>[exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
  }

  test('missing sync_mode preference defaults to manual', () async {
    final dt = controller();
    expect(await dt.getSyncMode(), TimeSyncMode.manual);
  });

  test('setSyncMode(network) calls timedatectl set-ntp true', () async {
    final dt = controller();
    await dt.setSyncMode(TimeSyncMode.network);
    expect(
      calls.any((c) =>
          c.length >= 3 &&
          c[0] == 'timedatectl' &&
          c[1] == 'set-ntp' &&
          c[2] == 'true'),
      isTrue,
    );
    expect(await dt.getSyncMode(), TimeSyncMode.network);
  });

  test('setSyncMode(manual) calls timedatectl set-ntp false', () async {
    final dt = controller();
    await dt.setSyncMode(TimeSyncMode.manual);
    expect(
      calls.any((c) =>
          c.length >= 3 &&
          c[0] == 'timedatectl' &&
          c[1] == 'set-ntp' &&
          c[2] == 'false'),
      isTrue,
    );
    expect(await dt.getSyncMode(), TimeSyncMode.manual);
  });

  test('applyPersistedSyncMode enables NTP when prefs say network', () async {
    await File(confPath).writeAsString('sync_mode=network\n');
    final dt = controller();
    await dt.applyPersistedSyncMode();
    expect(
      calls.any((c) =>
          c.length >= 3 &&
          c[0] == 'timedatectl' &&
          c[1] == 'set-ntp' &&
          c[2] == 'true'),
      isTrue,
    );
  });

  test('setWallClock disables NTP before set-time then persists manual',
      () async {
    final dt = controller();
    await dt.setWallClock(DateTime(2026, 7, 31, 12, 0, 0));

    final ntpOffIdx = calls.indexWhere((c) =>
        c.length >= 3 &&
        c[0] == 'timedatectl' &&
        c[1] == 'set-ntp' &&
        c[2] == 'false');
    final setTimeIdx = calls.indexWhere(
      (c) => c.length >= 2 && c[0] == 'timedatectl' && c[1] == 'set-time',
    );
    expect(ntpOffIdx, greaterThanOrEqualTo(0));
    expect(setTimeIdx, greaterThan(ntpOffIdx));
    expect(await dt.getSyncMode(), TimeSyncMode.manual);
  });

  test('set-ntp failure is soft (does not throw)', () async {
    final dt = LinuxDateTimeController(
      preferencePath: confPath,
      legacySyncModePath: '${tmp.path}/missing-sync',
      legacyTimezonePath: '${tmp.path}/missing-tz',
      runProcess: (exe, args) async {
        if (exe == 'timedatectl' && args.isNotEmpty && args.first == 'set-ntp') {
          return ProcessResult(0, 1, '', 'no timesyncd');
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    await expectLater(dt.setSyncMode(TimeSyncMode.network), completes);
  });
}
