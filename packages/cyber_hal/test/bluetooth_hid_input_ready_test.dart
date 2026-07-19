import 'package:cyber_hal/bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isBluetoothHidInputReady', () {
    test('true only when connected, services resolved, and evdev present', () {
      expect(
        isBluetoothHidInputReady(
          connected: true,
          servicesResolved: true,
          hasEvdev: true,
        ),
        isTrue,
      );
    });

    test('false when Connected with stale uhid but ServicesResolved=no', () {
      expect(
        isBluetoothHidInputReady(
          connected: true,
          servicesResolved: false,
          hasEvdev: true,
        ),
        isFalse,
      );
    });

    test('false when Connected + SR but no evdev', () {
      expect(
        isBluetoothHidInputReady(
          connected: true,
          servicesResolved: true,
          hasEvdev: false,
        ),
        isFalse,
      );
    });

    test('false when disconnected even if evdev residual', () {
      expect(
        isBluetoothHidInputReady(
          connected: false,
          servicesResolved: false,
          hasEvdev: true,
        ),
        isFalse,
      );
    });
  });
}
