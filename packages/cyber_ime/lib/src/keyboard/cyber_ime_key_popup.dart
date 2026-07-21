import 'package:cyber_ime/src/keyboard/cyber_ime_key.dart';
import 'package:cyber_ime/src/keyboard/cyber_ime_key_gestures.dart';

extension CyberImeKeyPopup on CyberImeKeyDef {
  bool get supportsAlternatePopup =>
      isLetter || _hasDualPopupOptions;

  bool get _hasDualPopupOptions =>
      (id == CyberImeKeyId.commaPeriod || id == CyberImeKeyId.custom) &&
      secondary != null &&
      secondary!.isNotEmpty;

  /// Options shown in the long-press floating popup (lws-ui `popupOptions`).
  List<String> popupOptions() {
    if (_hasDualPopupOptions) {
      return [primary, secondary!];
    }
    if (isLetter) {
      return [
        primary.toUpperCase(),
        if (secondary != null && secondary!.isNotEmpty) secondary!,
        primary.toLowerCase(),
      ];
    }
    return const [];
  }

  /// Default highlighted index (lws-ui: middle for 3+, else 0).
  int defaultPopupIndex() => cyberImeDefaultPopupIndex(popupOptions().length);
}
