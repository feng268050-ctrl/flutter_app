import 'package:cyber_hal/input/keyboard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/product_keyboard_profile.dart';

void main() {
  test('five segment labels', () {
    expect(
      ProductKeyboardProfile.values.map((e) => e.segmentLabel).toList(),
      ['Default', 'QWERTY', 'QWERTZ', 'AZERTY', 'JIS'],
    );
  });

  test('profile ↔ conf softProfile round-trip', () {
    for (final profile in ProductKeyboardProfile.values) {
      final layout = profile.xkbLayout;
      expect(layout.softProfile, profile.confProfileId);
      expect(ProductKeyboardProfile.fromLayout(layout), profile);
    }
  });

  test('XKB id alone still maps DE/FR/JP', () {
    expect(
      ProductKeyboardProfile.fromLayout(const KeyboardLayout(id: 'de')),
      ProductKeyboardProfile.qwertz,
    );
    expect(
      ProductKeyboardProfile.fromLayout(const KeyboardLayout(id: 'us')),
      ProductKeyboardProfile.ansi,
    );
  });

  test('JIS uses jp106 model', () {
    expect(ProductKeyboardProfile.jis.xkbLayout.id, 'jp');
    expect(ProductKeyboardProfile.jis.xkbLayout.model, 'jp106');
  });
}
