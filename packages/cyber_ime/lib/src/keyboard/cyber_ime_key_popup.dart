import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_gestures.dart';

extension CyberImeKeyPopup on CyberImeKeyDef {
  bool get supportsAlternatePopup =>
      isLetter || _hasShiftLayerPopup || _hasDualPopupOptions;

  bool get _hasDualPopupOptions =>
      (id == CyberImeKeyId.commaPeriod || id == CyberImeKeyId.custom) &&
      secondary != null &&
      secondary!.isNotEmpty;

  /// Digit / symbol KeyCode keys with a distinct Shift glyph.
  bool get _hasShiftLayerPopup =>
      keyCode != null &&
      !isLetter &&
      secondary != null &&
      secondary!.isNotEmpty &&
      secondary != primary;

  /// Options shown in the long-press floating popup (lws-ui `popupOptions`).
  ///
  /// Order is always normal → Shift (→ optional AltGr / phone digit), so
  /// horizontal slide picks the second function layer.
  List<String> popupOptions() {
    if (keyCode != null && isLetter) {
      final lower = primary.toLowerCase();
      final upper = primary.toUpperCase();
      final sec = secondary;
      // Phone digit / AltGr third option (not a case twin).
      if (sec != null &&
          sec.isNotEmpty &&
          sec.toLowerCase() != lower &&
          sec.toUpperCase() != upper) {
        return [upper, sec, lower];
      }
      // ANSI / typewriter Shift layer: normal then Shift.
      return [lower, upper];
    }
    if (_hasShiftLayerPopup || _hasDualPopupOptions) {
      return [primary, secondary!];
    }
    if (isLetter) {
      return [
        primary.toLowerCase(),
        primary.toUpperCase(),
      ];
    }
    return const [];
  }

  /// Default highlighted index (lws-ui: middle for 3+, else 0).
  int defaultPopupIndex() => cyberImeDefaultPopupIndex(popupOptions().length);
}
