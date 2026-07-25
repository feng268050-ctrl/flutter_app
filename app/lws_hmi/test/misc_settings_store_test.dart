import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';

void main() {
  test('defaults when JSON missing', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final store = MiscSettingsStore(
      preferencePath: '${dir.path}/misc-settings.json',
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      legacyAutoCheckOtaPath: '${dir.path}/auto-check-ota.json',
    );
    store.warmRead();
    expect(store.showStartupSelfCheck, isTrue);
    expect(store.showSystemStatusOverlay, isFalse);
    expect(store.autoCheckOtaUpdate, isFalse);
    await dir.delete(recursive: true);
  });

  test('JSON round-trip for overlay and self-check', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final path = '${dir.path}/misc-settings.json';
    final store = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      legacyAutoCheckOtaPath: '${dir.path}/auto-check-ota.json',
    );
    store.warmRead();
    await store.setShowSystemStatusOverlay(true);
    await store.setShowStartupSelfCheck(false);
    await store.setAutoCheckOtaUpdate(true);

    final again = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      legacyAutoCheckOtaPath: '${dir.path}/auto-check-ota.json',
    );
    again.warmRead();
    expect(again.showSystemStatusOverlay, isTrue);
    expect(again.showStartupSelfCheck, isFalse);
    expect(again.autoCheckOtaUpdate, isTrue);

    final decoded = jsonDecode(await File(path).readAsString()) as Map;
    expect(decoded['showSystemStatusOverlay'], isTrue);
    expect(decoded['showStartupSelfCheck'], isFalse);
    expect(decoded['autoCheckOtaUpdate'], isTrue);
    expect(decoded.containsKey('hideEngineerModeEntryTip'), isFalse);

    await dir.delete(recursive: true);
  });

  test('strips obsolete hideEngineerModeEntryTip on read', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final path = '${dir.path}/misc-settings.json';
    await File(path).writeAsString(
      '${const JsonEncoder.withIndent('  ').convert({
            'showStartupSelfCheck': true,
            'showSystemStatusOverlay': false,
            'showGroundLockAlarm': false,
            'autoCheckOtaUpdate': false,
            'hideEngineerModeEntryTip': true,
          })}\n',
    );

    final store = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      legacyAutoCheckOtaPath: '${dir.path}/auto-check-ota.json',
    );
    store.warmRead();

    final decoded = jsonDecode(await File(path).readAsString()) as Map;
    expect(decoded.containsKey('hideEngineerModeEntryTip'), isFalse);

    await dir.delete(recursive: true);
  });

  test('imports legacy boot-self-check when JSON absent', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final legacy = File('${dir.path}/boot-self-check');
    await legacy.writeAsString('0\n');
    final path = '${dir.path}/misc-settings.json';

    final store = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: legacy.path,
    );
    store.warmRead();
    expect(store.showStartupSelfCheck, isFalse);
    expect(store.showSystemStatusOverlay, isFalse);
    expect(File(path).existsSync(), isTrue);

    final again = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: legacy.path,
    );
    again.warmRead();
    expect(again.showStartupSelfCheck, isFalse);

    await dir.delete(recursive: true);
  });

  test('imports legacy auto-check-ota when JSON absent', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final legacy = File('${dir.path}/auto-check-ota.json');
    await legacy.writeAsString('{"enabled":true}\n');
    final path = '${dir.path}/misc-settings.json';

    final store = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
      legacyAutoCheckOtaPath: legacy.path,
    );
    store.warmRead();
    expect(store.autoCheckOtaUpdate, isTrue);
    expect(File(path).existsSync(), isTrue);

    final decoded = jsonDecode(await File(path).readAsString()) as Map;
    expect(decoded['autoCheckOtaUpdate'], isTrue);

    await dir.delete(recursive: true);
  });

  test('corrupt JSON soft-fails to defaults', () async {
    final dir = await Directory.systemTemp.createTemp('misc-');
    final path = '${dir.path}/misc-settings.json';
    await File(path).writeAsString('not-json{{{');
    final store = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
    );
    store.warmRead();
    expect(store.showStartupSelfCheck, isTrue);
    expect(store.showSystemStatusOverlay, isFalse);
    await dir.delete(recursive: true);
  });
}
