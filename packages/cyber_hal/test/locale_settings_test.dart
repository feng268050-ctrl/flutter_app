import 'dart:io';

import 'package:cyber_hal/datetime.dart';
import 'package:cyber_hal/locale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocaleSettings', () {
    late Directory tmp;
    late String path;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('locale_settings_');
      path = '${tmp.path}/locale.conf';
    });

    tearDown(() {
      if (tmp.existsSync()) {
        tmp.deleteSync(recursive: true);
      }
    });

    test('defaults when absent', () {
      final s = LocaleSettings(preferencePath: path);
      s.warmRead();
      expect(s.language, PreferredLanguage.enUs);
      expect(s.unit, UnitSystem.metric);
      expect(s.region, 'US');
      expect(s.hadPersistedRegion, isFalse);
    });

    test('persist and restore region', () async {
      final s = LocaleSettings(preferencePath: path);
      await s.setLanguage(PreferredLanguage.zhCn);
      await s.setUnit(UnitSystem.imperial);
      await s.setRegion('DE');

      final raw = File(path).readAsStringSync();
      expect(raw, contains('language=zh-CN'));
      expect(raw, contains('unit=Imperial'));
      expect(raw, contains('region=DE'));
      expect(raw, isNot(contains('country=')));

      final again = LocaleSettings(preferencePath: path);
      again.warmRead();
      expect(again.language, PreferredLanguage.zhCn);
      expect(again.unit, UnitSystem.imperial);
      expect(again.region, 'DE');
      expect(again.hadPersistedRegion, isTrue);
    });

    test('ignores common-settings style country key in conf', () {
      File(path).writeAsStringSync('language=en-US\nunit=Metric\ncountry=DE\n');
      final s = LocaleSettings(preferencePath: path);
      s.warmRead();
      expect(s.region, 'US');
      expect(s.hadPersistedRegion, isFalse);
    });
  });

  group('RegionSettingsPolicy', () {
    test('first apply migrates Asia/Shanghai and China NTP to US defaults', () {
      final plan = RegionSettingsPolicy.planClockApply(
        previousRegion: null,
        nextRegion: 'US',
        currentTimezone: 'Asia/Shanghai',
        autoTimezone: false,
        currentNtp: 'cn.pool.ntp.org',
      );
      expect(plan.applyTimezone, isTrue);
      expect(plan.timezone, 'America/New_York');
      expect(plan.applyNtp, isTrue);
      expect(plan.ntpServerId, 'pool.ntp.org');
    });

    test('US to DE updates linked timezone and NTP', () {
      final plan = RegionSettingsPolicy.planClockApply(
        previousRegion: 'US',
        nextRegion: 'DE',
        currentTimezone: 'America/New_York',
        autoTimezone: false,
        currentNtp: 'pool.ntp.org',
      );
      expect(plan.applyTimezone, isTrue);
      expect(plan.timezone, 'Europe/Berlin');
      expect(plan.applyNtp, isTrue);
    });

    test('custom timezone is preserved', () {
      final plan = RegionSettingsPolicy.planClockApply(
        previousRegion: 'US',
        nextRegion: 'DE',
        currentTimezone: 'America/Los_Angeles',
        autoTimezone: false,
        currentNtp: 'time.cloudflare.com',
      );
      expect(plan.applyTimezone, isFalse);
      expect(plan.applyNtp, isFalse);
    });

    test('auto_timezone skips timezone overwrite', () {
      final plan = RegionSettingsPolicy.planClockApply(
        previousRegion: 'US',
        nextRegion: 'DE',
        currentTimezone: 'America/New_York',
        autoTimezone: true,
        currentNtp: 'pool.ntp.org',
      );
      expect(plan.applyTimezone, isFalse);
      expect(plan.applyNtp, isTrue);
    });
  });

  group('RegionSettingsApplier', () {
    test('applyAfterWarmRead seeds region and calls wifi', () async {
      final tmp = Directory.systemTemp.createTempSync('locale_apply_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = '${tmp.path}/locale.conf';
      final settings = LocaleSettings(preferencePath: path);
      final dt = _FakeDateTime();
      final wifiCalls = <String>[];
      final applier = RegionSettingsApplier(
        dateTime: dt,
        applyWifiCountry: (cc) async {
          wifiCalls.add(cc);
          return true;
        },
      );
      await applier.applyAfterWarmRead(settings);
      expect(wifiCalls, ['US']);
      expect(settings.hadPersistedRegion, isTrue);
      expect(File(path).readAsStringSync(), contains('region=US'));
      expect(dt.timezone, 'America/New_York');
    });
  });
}

final class _FakeDateTime implements DateTimeController {
  String timezone = 'Asia/Shanghai';
  String ntp = 'cn.pool.ntp.org';
  bool autoTz = false;

  @override
  Future<bool> getAutoTimezone() async => autoTz;

  @override
  Future<String> getNtpServerId() async => ntp;

  @override
  Future<String> getTimezone() async => timezone;

  @override
  Future<void> setNtpServerId(String id) async {
    ntp = id;
  }

  @override
  Future<void> setTimezone(String id) async {
    timezone = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
