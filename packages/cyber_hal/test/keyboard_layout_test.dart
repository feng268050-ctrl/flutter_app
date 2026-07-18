import 'dart:io';

import 'package:cyber_hal/src/input/linux_keyboard.dart';
import 'package:cyber_hal/input/keyboard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse/encode keyboard.conf round-trip', () {
    const original = KeyboardLayout(
      id: 'ru',
      variant: '',
      options: 'grp:alt_shift_toggle',
      model: 'pc105',
    );
    final again = parseKeyboardConf(encodeKeyboardConf(original));
    expect(again.id, 'ru');
    expect(again.options, 'grp:alt_shift_toggle');
    expect(again.model, 'pc105');
  });

  test('parseEtcDefaultKeyboard reads XKBLAYOUT', () {
    final layout = parseEtcDefaultKeyboard('''
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS=""
''');
    expect(layout.id, 'us');
  });

  test('setLayout writes pref without restart when disabled', () async {
    final tmp = await Directory.systemTemp.createTemp('lws-kbd-');
    addTearDown(() => tmp.delete(recursive: true));
    final pref = File('${tmp.path}/keyboard.conf');
    final etc = File('${tmp.path}/default-keyboard');

    var restarts = 0;
    final kbd = LinuxKeyboard(
      preferencePath: pref.path,
      etcDefaultKeyboardPath: etc.path,
      applyRestart: true,
      restartHmi: () async {
        restarts++;
        return 0;
      },
    );

    await kbd.setLayout(LinuxKeyboard.ru);
    expect(await pref.exists(), isTrue);
    expect((await pref.readAsString()).contains('layout=ru'), isTrue);
    expect(await etc.exists(), isTrue);
    expect(restarts, 1);
    expect((await kbd.getLayout()).id, 'ru');
    expect(await kbd.listLayouts(), hasLength(2));
  });
}
