import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/datetime/date_time_controller.dart';
import 'package:lws_hmi/platform/datetime/linux_date_time_controller.dart';

void main() {
  group('TimeSyncPrefs', () {
    test('default / unknown token is network', () {
      expect(TimeSyncPrefs.modeFromToken(null), TimeSyncMode.network);
      expect(TimeSyncPrefs.modeFromToken(''), TimeSyncMode.network);
      expect(TimeSyncPrefs.modeFromToken('auto'), TimeSyncMode.network);
    });

    test('parses manual case-insensitively', () {
      expect(TimeSyncPrefs.modeFromToken('manual\n'), TimeSyncMode.manual);
      expect(TimeSyncPrefs.modeFromToken('MANUAL'), TimeSyncMode.manual);
    });

    test('sane UTC year window matches board helper', () {
      expect(TimeSyncPrefs.isSaneUtcYear(2024), isFalse);
      expect(TimeSyncPrefs.isSaneUtcYear(2025), isTrue);
      expect(TimeSyncPrefs.isSaneUtcYear(2030), isTrue);
      expect(TimeSyncPrefs.isSaneUtcYear(2031), isFalse);
    });

    test('normalizeTimezone defaults empty to UTC', () {
      expect(TimeSyncPrefs.normalizeTimezone(null), 'UTC');
      expect(TimeSyncPrefs.normalizeTimezone('  Asia/Shanghai '), 'Asia/Shanghai');
    });

    test('curated list includes China product default', () {
      expect(TimeSyncPrefs.curatedTimezones, contains('Asia/Shanghai'));
      expect(TimeSyncPrefs.curatedTimezones, contains('UTC'));
    });
  });

  group('LinuxDateTimeController prefs', () {
    late Directory tmp;
    late String modePath;
    late String tzPath;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('lws-datetime-');
      modePath = '${tmp.path}/time-sync-mode';
      tzPath = '${tmp.path}/timezone';
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('getSyncMode defaults to network when file missing', () async {
      final c = LinuxDateTimeController(
        syncModePath: modePath,
        timezonePath: tzPath,
        runProcess: (exe, args) async => ProcessResult(0, 1, '', 'skip'),
      );
      expect(await c.getSyncMode(), TimeSyncMode.network);
    });

    test('setSyncMode persists manual', () async {
      final c = LinuxDateTimeController(
        syncModePath: modePath,
        timezonePath: tzPath,
        runProcess: (exe, args) async => ProcessResult(0, 0, '', ''),
      );
      await c.setSyncMode(TimeSyncMode.manual);
      expect(await File(modePath).readAsString(), 'manual');
      expect(await c.getSyncMode(), TimeSyncMode.manual);
    });

    test('setWallClock switches mode to manual on success', () async {
      final calls = <String>[];
      final c = LinuxDateTimeController(
        syncModePath: modePath,
        timezonePath: tzPath,
        helperPath: '${tmp.path}/missing-helper',
        runProcess: (exe, args) async {
          calls.add('$exe ${args.join(' ')}');
          if (exe == 'timedatectl' && args.isNotEmpty && args.first == 'set-time') {
            return ProcessResult(0, 0, '', '');
          }
          if (exe == 'hwclock') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 1, '', 'fail');
        },
      );
      await c.setWallClock(DateTime(2026, 7, 15, 16, 0, 0));
      expect(await c.getSyncMode(), TimeSyncMode.manual);
      expect(calls.any((e) => e.startsWith('timedatectl set-time')), isTrue);
    });

    test('syncFromNetwork onlyIfStale no-ops when year sane', () async {
      // Host year is almost certainly 2026 during development; if not, skip.
      if (!TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
        return;
      }
      var ran = false;
      final c = LinuxDateTimeController(
        syncModePath: modePath,
        timezonePath: tzPath,
        helperPath: '${tmp.path}/missing-helper',
        runProcess: (exe, args) async {
          ran = true;
          return ProcessResult(0, 1, '', '');
        },
      );
      final r = await c.syncFromNetwork(onlyIfStale: true);
      expect(r.ok, isTrue);
      expect(ran, isFalse);
    });

    test('setTimezone writes preference file', () async {
      final c = LinuxDateTimeController(
        syncModePath: modePath,
        timezonePath: tzPath,
        runProcess: (exe, args) async => ProcessResult(0, 1, '', 'no td'),
      );
      await c.setTimezone('Asia/Shanghai');
      expect(await File(tzPath).readAsString(), 'Asia/Shanghai');
      expect(await c.getTimezone(), 'Asia/Shanghai');
    });
  });
}
