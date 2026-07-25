import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/input/usb_hid_keyboard_probe.dart';

void main() {
  test('UsbHidKeyboardProbe constructs', () {
    expect(const UsbHidKeyboardProbe(), isNotNull);
  });
}
