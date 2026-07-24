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
    expect(store.unit, CommonSettingsStore.defaultUnit);
    expect(File('${dir.path}/common-settings.json').existsSync(), isFalse);
    await dir.delete(recursive: true);
  });

  test('JSON round-trip for language and unit', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    await store.setLanguage(CommonSettingsStore.languageZh);
    await store.setUnit(CommonSettingsStore.unitImperial);

    final again = CommonSettingsStore(preferencePath: path);
    again.warmRead();
    expect(again.language, CommonSettingsStore.languageZh);
    expect(again.unit, CommonSettingsStore.unitImperial);

    final decoded = jsonDecode(await File(path).readAsString()) as Map;
    expect(decoded['language'], 'ZH');
    expect(decoded['unit'], 'Imperial');

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
    await dir.delete(recursive: true);
  });

  test('invalid values normalize to defaults', () async {
    final dir = await Directory.systemTemp.createTemp('common-');
    final path = '${dir.path}/common-settings.json';
    await File(path).writeAsString(
      jsonEncode({'language': 'FR', 'unit': 'Stone'}),
    );
    final store = CommonSettingsStore(preferencePath: path);
    store.warmRead();
    expect(store.language, CommonSettingsStore.defaultLanguage);
    expect(store.unit, CommonSettingsStore.defaultUnit);
    await dir.delete(recursive: true);
  });

  test('normalize helpers clamp unknown codes', () {
    expect(
      CommonSettingsStore.normalizeLanguage('ZH'),
      CommonSettingsStore.languageZh,
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
  });
}
