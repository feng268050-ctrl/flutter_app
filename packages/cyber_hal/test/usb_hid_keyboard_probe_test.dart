import 'dart:io';

import 'package:cyber_hal/input/keyboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UsbHidKeyboardProbe constructs', () {
    expect(const UsbHidKeyboardProbe(), isNotNull);
  });

  test('looksLikeKeyboardName matches kbd and keyboard', () {
    expect(
      UsbHidKeyboardProbe.looksLikeKeyboardName('usb-Foo-event-kbd'),
      isTrue,
    );
    expect(
      UsbHidKeyboardProbe.looksLikeKeyboardName(
        'bluetooth-Bar-event-keyboard',
      ),
      isTrue,
    );
    expect(
      UsbHidKeyboardProbe.looksLikeKeyboardName('usb-Foo-event-mouse'),
      isFalse,
    );
  });

  test('followLinks:false listing finds symlink basenames', () async {
    final dir = await Directory.systemTemp.createTemp('kbd-probe-');
    addTearDown(() => dir.delete(recursive: true));
    final target = File('${dir.path}/event0');
    await target.writeAsString('');
    await Link('${dir.path}/usb-Test-event-kbd').create(target.path);

    // Default list() follows links → File, not Link (the old bug).
    final followed = await dir.list().where((e) => e is Link).length;
    expect(followed, 0);

    final names = await UsbHidKeyboardProbe.keyboardLinksIn(dir.path);
    expect(names, ['usb-Test-event-kbd']);
  });
}
