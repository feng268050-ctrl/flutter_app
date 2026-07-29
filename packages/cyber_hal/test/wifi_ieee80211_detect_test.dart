import 'package:cyber_hal/src/network/wifi_radio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wifiUeventIsWlan', () {
    test('accepts DEVTYPE=wlan', () {
      expect(
        wifiUeventIsWlan('DEVTYPE=wlan\nINTERFACE=wlan0\nIFINDEX=4\n'),
        isTrue,
      );
    });

    test('rejects ether / missing DEVTYPE', () {
      expect(
        wifiUeventIsWlan('INTERFACE=eth0\nIFINDEX=2\n'),
        isFalse,
      );
      expect(
        wifiUeventIsWlan('DEVTYPE=bond_slave\nINTERFACE=eth0\n'),
        isFalse,
      );
    });

    test('trims whitespace around DEVTYPE line', () {
      expect(wifiUeventIsWlan('  DEVTYPE=wlan  \n'), isTrue);
    });
  });
}
