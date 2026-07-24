import 'package:cyber_ime/cyber_ime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => CyberImePhysicalKeyboard.register(null));

  test('unregistered detector means not present', () async {
    expect(await CyberImePhysicalKeyboard.isPresent(), isFalse);
  });

  test('Fixed detector reports configured presence', () async {
    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(true),
    );
    expect(await CyberImePhysicalKeyboard.isPresent(), isTrue);

    CyberImePhysicalKeyboard.register(
      const CyberImeFixedPhysicalKeyboardDetector(false),
    );
    expect(await CyberImePhysicalKeyboard.isPresent(), isFalse);
  });

  test('Callback detector forwards to HAL-style callback', () async {
    var calls = 0;
    CyberImePhysicalKeyboard.register(
      CyberImeCallbackPhysicalKeyboardDetector(() async {
        calls++;
        return true;
      }),
    );
    expect(await CyberImePhysicalKeyboard.isPresent(), isTrue);
    expect(calls, 1);
  });
}
