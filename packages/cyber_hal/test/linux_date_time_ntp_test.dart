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

  test('missing sync_mode preference defaults to network', () async {
    final dt = controller();
    expect(await dt.getSyncMode(), TimeSyncMode.network);
  });

  test('applyPersistedSyncMode enables NTP when prefs absent (default network)',
      () async {
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

  test('NtpServerCatalog defaults and drop-in rendering', () {
    expect(NtpServerCatalog.presets, hasLength(8));
    expect(NtpServerCatalog.normalizeId(null), NtpServerCatalog.defaultId);
    expect(NtpServerCatalog.normalizeId('nope'), 'pool.ntp.org');
    expect(NtpServerCatalog.normalizeId('time.google.com'), 'time.google.com');

    final body = NtpServerCatalog.renderTimesyncdDropIn('time.cloudflare.com');
    expect(body, contains('NTP=time.cloudflare.com'));
    expect(body, contains('FallbackNTP='));
    expect(body, contains('pool.ntp.org'));
    expect(body, isNot(contains('FallbackNTP=time.cloudflare.com')));
    expect(body.split('\n').where((l) => l.startsWith('NTP=')).single,
        'NTP=time.cloudflare.com');
  });

  test('TimezoneGeoParse json and plain', () {
    expect(
      TimezoneGeoParse.fromJsonTimezoneField(
        '{"status":"success","timezone":"America/Los_Angeles"}',
      ),
      'America/Los_Angeles',
    );
    expect(TimezoneGeoParse.fromJsonTimezoneField('{"unixtime":1}'), isNull);
    expect(
      TimezoneGeoParse.fromPlainTimezone('Asia/Shanghai\n'),
      'Asia/Shanghai',
    );
    expect(TimezoneGeoParse.fromPlainTimezone('<html>'), isNull);
  });

  test('auto_timezone defaults off and persists', () async {
    final dt = controller();
    expect(await dt.getAutoTimezone(), isFalse);
    await dt.setAutoTimezone(false);
    final conf = await File(confPath).readAsString();
    expect(conf, contains('auto_timezone=0'));
    expect(await dt.getAutoTimezone(), isFalse);
  });

  test('setNtpServerId persists and writes timesyncd drop-in', () async {
    final dropIn = '${tmp.path}/20-hmi-ntp.conf';
    final dt = LinuxDateTimeController(
      preferencePath: confPath,
      legacySyncModePath: '${tmp.path}/missing-sync',
      legacyTimezonePath: '${tmp.path}/missing-tz',
      timesyncdDropInPath: dropIn,
      runProcess: (exe, args) async {
        calls.add(<String>[exe, ...args]);
        return ProcessResult(0, 0, '', '');
      },
    );
    expect(await dt.getNtpServerId(), 'pool.ntp.org');
    await dt.setNtpServerId('ntp.aliyun.com');
    expect(await dt.getNtpServerId(), 'ntp.aliyun.com');
    final conf = await File(confPath).readAsString();
    expect(conf, contains('ntp_server=ntp.aliyun.com'));
    final body = await File(dropIn).readAsString();
    expect(body, contains('NTP=ntp.aliyun.com'));
    expect(body, contains('pool.ntp.org'));
    expect(
      calls.any((c) =>
          c.length >= 3 &&
          c[0] == 'systemctl' &&
          c[1] == 'restart' &&
          c[2] == 'systemd-timesyncd.service'),
      isTrue,
    );
  });

  test('syncTimezoneFromNetwork uses ip-api then setTimezone', () async {
    final dt = LinuxDateTimeController(
      preferencePath: confPath,
      legacySyncModePath: '${tmp.path}/missing-sync',
      legacyTimezonePath: '${tmp.path}/missing-tz',
      timesyncdDropInPath: '${tmp.path}/20-hmi-ntp.conf',
      runProcess: (exe, args) async {
        calls.add(<String>[exe, ...args]);
        if (exe == 'wget' && args.any((a) => a.contains('ip-api.com/json'))) {
          return ProcessResult(
            0,
            0,
            '{"status":"success","timezone":"Europe/Berlin"}',
            '',
          );
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    final r = await dt.syncTimezoneFromNetwork();
    expect(r.ok, isTrue);
    expect(await dt.getTimezone(), 'Europe/Berlin');
    expect(
      calls.any((c) =>
          c.length >= 3 &&
          c[0] == 'timedatectl' &&
          c[1] == 'set-timezone' &&
          c[2] == 'Europe/Berlin'),
      isTrue,
    );
  });

  test('use_24h defaults on and persists off', () async {
    final dt = controller();
    expect(await dt.getUse24HourFormat(), isTrue);
    await dt.setUse24HourFormat(false);
    final conf = await File(confPath).readAsString();
    expect(conf, contains('use_24h=0'));
    expect(await dt.getUse24HourFormat(), isFalse);
  });

  test('TimeDisplayFormat 12h and 24h', () {
    final t = DateTime(2026, 8, 1, 15, 5);
    expect(TimeDisplayFormat.formatHm(t, use24Hour: true), '15:05');
    expect(TimeDisplayFormat.formatHm(t, use24Hour: false), '3:05 PM');
    expect(
      TimeDisplayFormat.formatHm(DateTime(2026, 8, 1, 0, 0), use24Hour: false),
      '12:00 AM',
    );
  });

  test('setAutoTimezone(true) keeps pref when geo fails', () async {
    final dt = LinuxDateTimeController(
      preferencePath: confPath,
      legacySyncModePath: '${tmp.path}/missing-sync',
      legacyTimezonePath: '${tmp.path}/missing-tz',
      timesyncdDropInPath: '${tmp.path}/20-hmi-ntp.conf',
      runProcess: (exe, args) async {
        if (exe == 'wget') {
          return ProcessResult(0, 1, '', 'fail');
        }
        return ProcessResult(0, 0, '', '');
      },
    );
    await dt.setTimezone('UTC');
    final r = await dt.setAutoTimezone(true);
    expect(r.ok, isFalse);
    expect(await dt.getAutoTimezone(), isTrue);
    expect(await dt.getTimezone(), 'UTC');
  });
}
