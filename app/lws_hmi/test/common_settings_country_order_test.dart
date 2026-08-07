import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/region_country_catalog.dart';

void main() {
  test('Common Settings source lists Country before Language', () {
    final src = File(
      'lib/features/settings/presentation/tabs/common_settings_tab.dart',
    ).readAsStringSync();
    final country = src.indexOf('l10n.countrySettingText');
    final language = src.indexOf('l10n.languageSettingText');
    expect(country, greaterThan(-1));
    expect(language, greaterThan(-1));
    expect(country, lessThan(language));
  });

  test('full ISO catalog defaults to US with non-China NTP', () {
    expect(RegionCountryCatalog.defaultCountry, 'US');
    expect(RegionCountryCatalog.supportedCodes.length, greaterThanOrEqualTo(240));
    expect(RegionCountryCatalog.isSupported('CN'), isTrue);
    expect(RegionCountryCatalog.isSupported('TW'), isTrue);
    expect(RegionCountryCatalog.isSupported('HK'), isTrue);
    expect(RegionCountryCatalog.isSupported('DE'), isTrue);
    expect(RegionCountryCatalog.isSupported('BR'), isTrue);
    expect(RegionCountryCatalog.normalize('xx'), 'US');
    for (final e in RegionCountryCatalog.entries) {
      expect(e.preferredNtp, isNot(RegionCountryCatalog.legacyChinaNtp));
      expect(e.code.length, 2);
      expect(e.nameEn, isNotEmpty);
      expect(e.nameZh, isNotEmpty);
      expect(e.defaultTimezone, isNotEmpty);
    }
  });

  test('filter matches code english and chinese', () {
    final byCode = RegionCountryCatalog.filter(
      RegionCountryCatalog.entries,
      'de',
    );
    expect(byCode.any((e) => e.code == 'DE'), isTrue);

    final byZh = RegionCountryCatalog.filter(
      RegionCountryCatalog.entries,
      '德国',
    );
    expect(byZh.single.code, 'DE');
  });

  test('sortedForDisplay is A-Z by English name', () {
    final sorted = RegionCountryCatalog.sortedForDisplay();
    expect(sorted, isNotEmpty);
    for (var i = 1; i < sorted.length; i++) {
      expect(
        sorted[i - 1].nameEn.toLowerCase().compareTo(
              sorted[i].nameEn.toLowerCase(),
            ),
        lessThanOrEqualTo(0),
      );
    }
    // Afghanistan before United States (no US pin).
    final af = sorted.indexWhere((e) => e.code == 'AF');
    final us = sorted.indexWhere((e) => e.code == 'US');
    expect(af, greaterThanOrEqualTo(0));
    expect(us, greaterThan(af));
  });
}
