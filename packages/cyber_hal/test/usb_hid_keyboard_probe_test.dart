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

  test('isBuiltinButtonDevice excludes board gpio/power keys', () {
    expect(UsbHidKeyboardProbe.isBuiltinButtonDevice('gpio-keys'), isTrue);
    expect(UsbHidKeyboardProbe.isBuiltinButtonDevice('adc-keys'), isTrue);
    expect(UsbHidKeyboardProbe.isBuiltinButtonDevice('rk809 pwrkey'), isTrue);
    expect(UsbHidKeyboardProbe.isBuiltinButtonDevice('rk805 pwrkey'), isTrue);
    expect(UsbHidKeyboardProbe.isBuiltinButtonDevice('bt-powerkey'), isTrue);
    expect(
      UsbHidKeyboardProbe.isBuiltinButtonDevice('Power Button'),
      isTrue,
    );
    expect(
      UsbHidKeyboardProbe.isBuiltinButtonDevice('Logitech USB Keyboard'),
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

  test('procKbdNames ignores gpio-keys but keeps USB keyboards', () async {
    final dir = await Directory.systemTemp.createTemp('proc-kbd-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/devices');
    await file.writeAsString('''
I: Bus=0019 Vendor=0001 Product=0001 Version=0100
N: Name="gpio-keys"
P: Phys=gpio-keys/input0
S: Sysfs=/devices/platform/gpio-keys/input/input0
U: Uniq=
H: Handlers=kbd event0
B: EV=3
B: KEY=100000 0 0 0

I: Bus=0003 Vendor=046d Product=c31c Version=0110
N: Name="Logitech USB Keyboard"
P: Phys=usb-xhci-hcd.0.auto-1.1/input0
S: Sysfs=/devices/platform/.../input/input2
U: Uniq=
H: Handlers=sysrq kbd event2 leds
B: EV=120013
B: KEY=10000 7 ff800000 7ff febeffdf ffffffff ffffffff fffffffe
''');

    final names = await UsbHidKeyboardProbe.procKbdNames(path: file.path);
    expect(names, ['Logitech USB Keyboard']);
  });

  test('procKbdNames empty when only board buttons present', () async {
    final dir = await Directory.systemTemp.createTemp('proc-builtin-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/devices');
    await file.writeAsString('''
I: Bus=0019 Vendor=0001 Product=0001 Version=0100
N: Name="gpio-keys"
P: Phys=gpio-keys/input0
H: Handlers=kbd event0
B: EV=3

I: Bus=0019 Vendor=0000 Product=0000 Version=0000
N: Name="rk805 pwrkey"
H: Handlers=kbd event0 dmcfreq

I: Bus=0019 Vendor=0000 Product=0000 Version=0000
N: Name="bt-powerkey"
H: Handlers=kbd event2 dmcfreq
''');

    final names = await UsbHidKeyboardProbe.procKbdNames(path: file.path);
    expect(names, isEmpty);
  });
}
