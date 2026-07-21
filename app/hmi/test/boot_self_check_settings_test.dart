import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_store.dart';
import 'dart:io';

void main() {
  test('default enabled via misc store when file missing', () async {
    final dir = await Directory.systemTemp.createTemp('boot-sc-');
    final misc = MiscSettingsStore(
      preferencePath: '${dir.path}/misc-settings.json',
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
    );
    final store = BootSelfCheckSettings(miscStore: misc);
    expect(store.warmRead(), isTrue);
    await dir.delete(recursive: true);
  });

  test('write and warmRead round-trip via misc JSON', () async {
    final dir = await Directory.systemTemp.createTemp('boot-sc-');
    final path = '${dir.path}/misc-settings.json';
    final misc = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
    );
    final store = BootSelfCheckSettings(miscStore: misc);

    expect(store.warmRead(), isTrue);
    await store.setEnabled(false);
    expect(store.isEnabled, isFalse);

    final againMisc = MiscSettingsStore(
      preferencePath: path,
      legacyBootSelfCheckPath: '${dir.path}/boot-self-check',
    );
    final again = BootSelfCheckSettings(miscStore: againMisc);
    expect(again.warmRead(), isFalse);

    await dir.delete(recursive: true);
  });

  test('enabledOverrideForTest wins', () {
    final store = BootSelfCheckSettings(enabledOverrideForTest: false);
    expect(store.warmRead(), isFalse);
    expect(store.isEnabled, isFalse);
  });
}
