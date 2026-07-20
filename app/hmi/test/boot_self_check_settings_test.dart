import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_settings.dart';

void main() {
  test('default enabled when file missing', () async {
    final dir = await Directory.systemTemp.createTemp('boot-sc-');
    final path = '${dir.path}/boot-self-check';
    final store = BootSelfCheckSettings(preferencePath: path);
    expect(store.warmRead(), isTrue);
    await dir.delete(recursive: true);
  });

  test('write and warmRead round-trip', () async {
    final dir = await Directory.systemTemp.createTemp('boot-sc-');
    final path = '${dir.path}/boot-self-check';
    final store = BootSelfCheckSettings(preferencePath: path);

    expect(store.warmRead(), isTrue);
    await store.setEnabled(false);
    expect(store.isEnabled, isFalse);

    final again = BootSelfCheckSettings(preferencePath: path);
    expect(again.warmRead(), isFalse);

    await dir.delete(recursive: true);
  });

  test('enabledOverrideForTest wins', () {
    final store = BootSelfCheckSettings(enabledOverrideForTest: false);
    expect(store.warmRead(), isFalse);
    expect(store.isEnabled, isFalse);
  });
}
