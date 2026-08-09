import 'dart:io';

import 'package:cyber_hal/locale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_locales.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('locale_settings_app_');
  });

  tearDown(() {
    if (tmp.existsSync()) {
      tmp.deleteSync(recursive: true);
    }
  });

  test('defaults when file absent', () {
    final store = LocaleSettings(
      preferencePath: '${tmp.path}/locale.conf',
    );
    store.warmRead();
    expect(store.language, PreferredLanguage.defaultValue);
    expect(store.language, PreferredLanguage.enUs);
    expect(store.unit, UnitSystem.defaultValue);
    expect(store.region, RegionCatalog.defaultRegion);
    expect(store.hadPersistedRegion, isFalse);
  });

  test('persist language unit region round-trip', () async {
    final path = '${tmp.path}/locale.conf';
    final store = LocaleSettings(preferencePath: path);
    await store.setLanguage(PreferredLanguage.zhCn);
    await store.setUnit(UnitSystem.imperial);
    await store.setRegion('DE');

    final again = LocaleSettings(preferencePath: path);
    again.warmRead();
    expect(again.language, PreferredLanguage.zhCn);
    expect(again.unit, UnitSystem.imperial);
    expect(again.region, 'DE');
    expect(again.hadPersistedRegion, isTrue);
    expect(localeFromLanguageTag(again.languageWire).languageCode, 'zh');
  });

  test('corrupt conf soft-fails to defaults', () {
    final path = '${tmp.path}/locale.conf';
    File(path).writeAsStringSync('{{{not-kv');
    final store = LocaleSettings(preferencePath: path);
    store.warmRead();
    // Unparseable lines ignored → empty map → defaults.
    expect(store.language, PreferredLanguage.defaultValue);
    expect(store.unit, UnitSystem.defaultValue);
    expect(store.region, RegionCatalog.defaultRegion);
  });
}
