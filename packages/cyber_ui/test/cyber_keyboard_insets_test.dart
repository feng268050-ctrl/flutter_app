import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CyberKeyboardInsets', () {
    test('centers when space allows', () {
      final ty = CyberKeyboardInsets.computeCardTranslationY(
        visibleTop: 0,
        visibleBottom: 1200,
        cardTop: 400,
        cardHeight: 200,
        keyboardHeight: 400,
        margin: 24,
      );
      expect(ty, closeTo(100, 0.01));
    });

    test('lifts above keyboard when space tight', () {
      final ty = CyberKeyboardInsets.computeCardTranslationY(
        visibleTop: 0,
        visibleBottom: 240,
        cardTop: 300,
        cardHeight: 200,
        keyboardHeight: 400,
        margin: 24,
      );
      expect(ty, closeTo(-276, 0.01));
    });

    test('returns zero when keyboard hidden', () {
      final ty = CyberKeyboardInsets.computeCardTranslationY(
        visibleTop: 0,
        visibleBottom: 1200,
        cardTop: 400,
        cardHeight: 200,
        keyboardHeight: 0,
        margin: 24,
      );
      expect(ty, 0);
    });
  });
}
