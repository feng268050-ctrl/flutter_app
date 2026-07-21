import 'dart:math' as math;

/// Card lift geometry aligned with lws-ui `ImeInsets.computeCardTranslationY`.
///
/// Returns a [Transform.translate] dy: negative moves the card up.
abstract final class CyberKeyboardInsets {
  static const double visibleThreshold = 80;
  static const double defaultMargin = 24;

  /// Compute vertical translation for a dialog card above a keyboard.
  ///
  /// When there is room, recenters the card in the remaining visible band.
  /// When space is tight, pins the card just above the keyboard (with [margin]).
  /// Does **not** blindly translate by the full keyboard height.
  static double computeCardTranslationY({
    required double visibleTop,
    required double visibleBottom,
    required double cardTop,
    required double cardHeight,
    required double keyboardHeight,
    double margin = defaultMargin,
  }) {
    if (keyboardHeight < visibleThreshold) {
      return 0;
    }
    final availableHeight = math.max(0.0, visibleBottom - visibleTop);
    final double targetTop;
    if (availableHeight > cardHeight + margin * 2) {
      targetTop = visibleTop + (availableHeight - cardHeight) / 2;
    } else {
      targetTop = math.max(
        visibleTop + margin,
        visibleBottom - cardHeight - margin,
      );
    }
    return targetTop - cardTop;
  }
}
