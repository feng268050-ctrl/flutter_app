import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wpaKeyMgmtRequiresPsk', () {
    test('open / empty / OWE do not require PSK', () {
      expect(wpaKeyMgmtRequiresPsk(const []), isFalse);
      expect(wpaKeyMgmtRequiresPsk(const ['none']), isFalse);
      expect(wpaKeyMgmtRequiresPsk(const ['owe']), isFalse);
      expect(wpaKeyMgmtRequiresPsk(const ['wpa-none']), isFalse);
    });

    test('PSK / SAE / WEP require passphrase', () {
      expect(wpaKeyMgmtRequiresPsk(const ['wpa-psk']), isTrue);
      expect(wpaKeyMgmtRequiresPsk(const ['wpa-ft-psk']), isTrue);
      expect(wpaKeyMgmtRequiresPsk(const ['sae']), isTrue);
      expect(wpaKeyMgmtRequiresPsk(const ['wep']), isTrue);
    });

    test('EAP alone does not require PSK dialog', () {
      expect(wpaKeyMgmtRequiresPsk(const ['wpa-eap']), isFalse);
      expect(wpaKeyMgmtRequiresPsk(const ['wpa-ft-eap']), isFalse);
    });
  });
}
