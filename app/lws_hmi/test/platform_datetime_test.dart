import 'dart:io';

import 'package:cyber_hal/src/linux/key_value_conf.dart';
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

    test('datetime.conf path and keys', () {
      expect(TimeSyncPrefs.datetimeConf, '/var/lib/hal/datetime.conf');
      expect(TimeSyncPrefs.keySyncMode, 'sync_mode');
      expect(TimeSyncPrefs.keyTimezone, 'timezone');
    });
  });

  group('LinuxDateTimeController prefs', () {
    late Directory tmp;
    late String confPath;
    late String legacyModePath;
    late String legacyTzPath;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('lws-datetime-');
      confPath = '${tmp.path}/datetime.conf';
      legacyModePath = '${tmp.path}/time-sync-mode';
      legacyTzPath = '${tmp.path}/timezone';
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    LinuxDateTimeController controller({
      DateTimeProcessRunner? runProcess,
      String? helperPath,
    }) {
      return LinuxDateTimeController(
        preferencePath: confPath,
        legacySyncModePath: legacyModePath,
        legacyTimezonePath: legacyTzPath,
        helperPath: helperPath ?? '${tmp.path}/missing-helper',
        runProcess: runProcess ??
            ((exe, args) async => ProcessResult(0, 1, '', 'skip')),
      );
    }

    test('getSyncMode defaults to network when conf missing', () async {
      final c = controller();
      expect(await c.getSyncMode(), TimeSyncMode.network);
    });

    test('setSyncMode persists manual in datetime.conf', () async {
      final c = controller(
        runProcess: (exe, args) async => ProcessResult(0, 0, '', ''),
      );
      await c.setSyncMode(TimeSyncMode.manual);
      final map = parseKeyValueConf(await File(confPath).readAsString());
      expect(map[TimeSyncPrefs.keySyncMode], 'manual');
      expect(await c.getSyncMode(), TimeSyncMode.manual);
    });

    test('setTimezone upsert preserves sync_mode sibling', () async {
      final c = controller(
        runProcess: (exe, args) async => ProcessResult(0, 1, '', 'no td'),
      );
      await c.setSyncMode(TimeSyncMode.manual);
      await c.setTimezone('Asia/Shanghai');
      final map = parseKeyValueConf(await File(confPath).readAsString());
      expect(map[TimeSyncPrefs.keySyncMode], 'manual');
      expect(map[TimeSyncPrefs.keyTimezone], 'Asia/Shanghai');
      expect(await c.getTimezone(), 'Asia/Shanghai');
    });

    test('legacy files migrate once into datetime.conf', () async {
      await File(legacyModePath).writeAsString('manual\n');
      await File(legacyTzPath).writeAsString('UTC\n');
      final c = controller();
      expect(await c.getSyncMode(), TimeSyncMode.manual);
      expect(await c.getTimezone(), 'UTC');
      final map = parseKeyValueConf(await File(confPath).readAsString());
      expect(map[TimeSyncPrefs.keySyncMode], 'manual');
      expect(map[TimeSyncPrefs.keyTimezone], 'UTC');
    });

    test('setWallClock switches mode to manual on success', () async {
      final calls = <String>[];
      final c = controller(
        runProcess: (exe, args) async {
          calls.add('$exe ${args.join(' ')}');
          if (exe == 'timedatectl' &&
              args.isNotEmpty &&
              args.first == 'set-time') {
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
      final c = controller(
        runProcess: (exe, args) async {
          ran = true;
          return ProcessResult(0, 1, '', '');
        },
      );
      final r = await c.syncFromNetwork(onlyIfStale: true);
      expect(r.ok, isTrue);
      expect(ran, isFalse);
    });
  });
}
