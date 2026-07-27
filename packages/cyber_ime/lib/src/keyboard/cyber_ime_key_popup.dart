import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_gestures.dart';

extension CyberImeKeyPopup on CyberImeKeyDef {
  bool get supportsAlternatePopup =>
      (longPressOptions != null && longPressOptions!.isNotEmpty) ||
      isLetter ||
      _hasShiftLayerPopup ||
      _hasDualPopupOptions;

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
  List<String> popupOptions() {
    final explicit = longPressOptions;
    if (explicit != null && explicit.isNotEmpty) {
      return List<String>.from(explicit);
    }
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
