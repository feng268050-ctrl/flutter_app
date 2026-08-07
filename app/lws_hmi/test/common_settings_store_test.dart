import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';

void main() {
  test('defaults when JSON missing', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final store = CommonSettingsStore(
      preferencePath: '${dir.path}/common-settings.json',
    );
    store.warmRead();
    expect(store.language, CommonSettingsStore.defaultLanguage);
    expect(store.language, CommonSettingsStore.languageEnUs);
    expect(store.unit, CommonSettingsStore.defaultUnit);
    expect(store.country, CommonSettingsStore.defaultCountry);
    expect(store.country, 'US');
    expect(store.hadPersistedCountry, isFalse);
    expect(File('${dir.path}/common-settings.json').existsSync(), isFalse);
    await dir.delete(recursive: true);
  });

  test('JSON round-trip for language unit and country', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    await store.setLanguage(CommonSettingsStore.languageZhCn);
    await store.setUnit(CommonSettingsStore.unitImperial);
    await store.setCountry('DE');

    final again = CommonSettingsStore(preferencePath: path);
    again.warmRead();
    expect(again.language, CommonSettingsStore.languageZhCn);
    expect(again.unit, CommonSettingsStore.unitImperial);
    expect(again.country, 'DE');
    expect(again.hadPersistedCountry, isTrue);

    final decoded = jsonDecode(await File(path).readAsString()) as Map;
    expect(decoded['language'], 'zh-CN');
    expect(decoded['unit'], 'Imperial');
    expect(decoded['country'], 'DE');

    await dir.delete(recursive: true);
  });

  test('legacy EN/ZH normalize on read', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    await File(path).writeAsString(
      jsonEncode({'language': 'ZH', 'unit': 'Metric'}),
    );
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    expect(store.language, CommonSettingsStore.languageZhCn);
    expect(store.isChineseLanguage, isTrue);
    expect(store.country, 'US');
    expect(store.hadPersistedCountry, isFalse);

    await File(path).writeAsString(
      jsonEncode({'language': 'EN', 'unit': 'Metric'}),
    );
    final enStore = CommonSettingsStore(preferencePath: path);
    enStore.warmRead();
    expect(enStore.language, CommonSettingsStore.languageEnUs);

    await dir.delete(recursive: true);
  });

  test('corrupt JSON soft-fails to defaults', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    await File(path).writeAsString('not-json{{{');
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    expect(store.language, CommonSettingsStore.defaultLanguage);
    expect(store.unit, CommonSettingsStore.defaultUnit);
    expect(store.country, CommonSettingsStore.defaultCountry);
    await dir.delete(recursive: true);
  });

  test('invalid values normalize to defaults', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    await File(path).writeAsString(
      jsonEncode({'language': 'FR', 'unit': 'Stone', 'country': 'XX'}),
    );
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    expect(store.language, CommonSettingsStore.defaultLanguage);
    expect(store.unit, CommonSettingsStore.defaultUnit);
    expect(store.country, CommonSettingsStore.defaultCountry);
    expect(store.hadPersistedCountry, isTrue);
    await dir.delete(recursive: true);
  });

  test('normalize helpers clamp unknown codes', () {
    expect(
      CommonSettingsStore.normalizeLanguage('ZH'),
      CommonSettingsStore.languageZhCn,
    );
    expect(
      CommonSettingsStore.normalizeLanguage('zh-TW'),
      CommonSettingsStore.languageZhTw,
    );
    expect(
      CommonSettingsStore.normalizeLanguage('nope'),
      CommonSettingsStore.defaultLanguage,
    );
    expect(
      CommonSettingsStore.normalizeUnit('Imperial'),
      CommonSettingsStore.unitImperial,
    );
    expect(
      CommonSettingsStore.normalizeUnit('nope'),
      CommonSettingsStore.defaultUnit,
    );
    expect(CommonSettingsStore.normalizeCountry('de'), 'DE');
    expect(CommonSettingsStore.normalizeCountry('nope'), 'US');
  });

  test('language endonyms are not locale-translated', () {
    expect(
      CommonSettingsStore.languageEndonym(CommonSettingsStore.languageEnUs),
      'English',
    );
    expect(
      CommonSettingsStore.languageEndonym(CommonSettingsStore.languageZhCn),
      '简体中文',
    );
    expect(
      CommonSettingsStore.languageEndonym(CommonSettingsStore.languageZhTw),
      '繁體中文',
    );
  });
}
