import 'package:cyber_hal/input/keyboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/product_keyboard_profile.dart';

void main() {
  test('three segment labels', () {
    expect(
      ProductKeyboardProfile.values.map((e) => e.segmentLabel).toList(),
      ['QWERTY', 'QWERTZ', 'AZERTY'],
    );
  });

  test('profile ↔ conf softProfile round-trip', () {
    for (final profile in ProductKeyboardProfile.values) {
      final layout = profile.xkbLayout;
      expect(layout.softProfile, profile.confProfileId);
      expect(ProductKeyboardProfile.fromLayout(layout), profile);
    }
  });

  test('legacy default/ansi/jis/jp migrate to qwerty', () {
    expect(
      ProductKeyboardProfile.fromConfProfile('default'),
      ProductKeyboardProfile.qwerty,
    );
    expect(
      ProductKeyboardProfile.fromConfProfile('ansi'),
      ProductKeyboardProfile.qwerty,
    );
    expect(
      ProductKeyboardProfile.fromConfProfile('jis'),
      ProductKeyboardProfile.qwerty,
    );
    expect(
      ProductKeyboardProfile.fromConfProfile('jp'),
      ProductKeyboardProfile.qwerty,
    );
    expect(ProductKeyboardProfile.qwerty.confProfileId, 'qwerty');
  });

  test('XKB id alone still maps DE/FR/US', () {
    expect(
      ProductKeyboardProfile.fromLayout(const KeyboardLayout(id: 'de')),
      ProductKeyboardProfile.qwertz,
    );
    expect(
      ProductKeyboardProfile.fromLayout(const KeyboardLayout(id: 'us')),
      ProductKeyboardProfile.qwerty,
    );
    expect(
      ProductKeyboardProfile.fromLayout(const KeyboardLayout(id: 'jp')),
      ProductKeyboardProfile.qwerty,
    );
  });
}
