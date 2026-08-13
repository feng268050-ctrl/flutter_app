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

  group('TimezoneCatalog', () {
    test('formats posix %z offsets', () {
      expect(TimezoneCatalog.formatPosixOffset('+0800'), 'UTC+08:00');
      expect(TimezoneCatalog.formatPosixOffset('-0530'), 'UTC-05:30');
      expect(TimezoneCatalog.formatPosixOffset('bogus'), '');
    });

    test('matches zone name and utc offset queries', () {
      const shanghai = TimezoneEntry(
        id: 'Asia/Shanghai',
        utcOffsetLabel: 'UTC+08:00',
      );
      expect(TimezoneCatalog.matchesQuery(shanghai, 'shang'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, 'Asia/Shanghai'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, '8'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, '+08'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, 'utc+8'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, 'UTC+08:00'), isTrue);
      expect(TimezoneCatalog.matchesQuery(shanghai, '-5'), isFalse);
    });

    test('filter prefers exact / suffix matches', () {
      const all = [
        TimezoneEntry(id: 'America/New_York', utcOffsetLabel: 'UTC-04:00'),
        TimezoneEntry(id: 'Asia/Shanghai', utcOffsetLabel: 'UTC+08:00'),
        TimezoneEntry(id: 'Australia/Sydney', utcOffsetLabel: 'UTC+10:00'),
      ];
      final byCity = TimezoneCatalog.filter(all, 'shanghai');
      expect(byCity.map((e) => e.id), ['Asia/Shanghai']);
      final byOffset = TimezoneCatalog.filter(all, '+08');
      expect(byOffset.map((e) => e.id), ['Asia/Shanghai']);
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

    test('now prefers date civil stamp over DateTime.now', () async {
      final c = controller(
        runProcess: (exe, args) async {
          if (exe == 'sh' &&
              args.length >= 2 &&
              args[1].contains('date +%Y-%m-%dT%H:%M:%S')) {
            return ProcessResult(0, 0, '2026-07-27T17:30:00\n', '');
          }
          if (exe == 'timedatectl' &&
              args.isNotEmpty &&
              args.first == 'set-timezone') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 1, '', 'fail');
        },
      );
      final n = await c.now();
      expect(n.year, 2026);
      expect(n.month, 7);
      expect(n.day, 27);
      expect(n.hour, 17);
      expect(n.minute, 30);
    });

    test('now passes pref timezone to date via TZ=', () async {
      await File(confPath).writeAsString('timezone=Asia/Shanghai\n');
      String? shCmd;
      final c = controller(
        runProcess: (exe, args) async {
          if (exe == 'sh' && args.length >= 2) {
            shCmd = args[1];
            if (args[1].contains('date +%Y-%m-%dT%H:%M:%S')) {
              return ProcessResult(0, 0, '2026-08-12T17:51:00\n', '');
            }
          }
          if (exe == 'timedatectl' &&
              args.isNotEmpty &&
              args.first == 'set-timezone') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 1, '', 'fail');
        },
      );
      final n = await c.now();
      expect(shCmd, contains("TZ='Asia/Shanghai'"));
      expect(n.hour, 17);
      expect(n.minute, 51);
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

    test('syncFromNetwork HTTP Date sets UTC stamp not local GMT fields', () async {
      if (!TimeSyncPrefs.isSaneUtcYear(DateTime.now().toUtc().year)) {
        return;
      }
      final calls = <String>[];
      await File(confPath).writeAsString(
        'sync_mode=network\ntimezone=Asia/Shanghai\n',
      );
      final c = controller(
        runProcess: (exe, args) async {
          calls.add('$exe ${args.join(' ')}');
          if (exe == 'timedatectl' &&
              args.isNotEmpty &&
              args.first == 'set-timezone') {
            return ProcessResult(0, 0, '', '');
          }
          if (exe == 'rdate') {
            return ProcessResult(0, 1, '', 'fail');
          }
          if (exe == 'wget') {
            return ProcessResult(
              0,
              0,
              '',
              '  Date: Sat, 25 Jul 2026 10:12:00 GMT\r\n',
            );
          }
          if (exe == 'timedatectl' &&
              args.isNotEmpty &&
              args.first == 'set-time') {
            // Prefer failing so we assert BusyBox date -u -s path.
            return ProcessResult(0, 1, '', 'no td');
          }
          if (exe == 'date' && args.contains('-u') && args.contains('-s')) {
            return ProcessResult(0, 0, '', '');
          }
          if (exe == 'hwclock') {
            return ProcessResult(0, 0, '', '');
          }
          return ProcessResult(0, 1, '', '');
        },
      );
      final r = await c.syncFromNetwork(onlyIfStale: false);
      expect(r.ok, isTrue);
      expect(
        calls.any((e) => e == 'date -u -s 2026-07-25 10:12:00'),
        isTrue,
        reason: 'HTTP Date GMT must become UTC civil stamp via date -u -s',
      );
      expect(
        calls.any((e) => e.contains('%a,') || e.contains('GMT')),
        isFalse,
        reason: 'must not pass raw HTTP Date into BusyBox -D parser',
      );
      expect(
        calls.any((e) => e == 'timedatectl set-timezone Asia/Shanghai'),
        isTrue,
      );
    });
  });
}
