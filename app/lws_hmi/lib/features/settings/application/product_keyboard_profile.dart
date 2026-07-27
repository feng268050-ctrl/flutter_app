import 'package:cyber_hal/input/keyboard.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// Product keyboard specification (Settings Segment + CyberIME + XKB).
///
/// Soft Segment labels: QWERTY / QWERTZ / AZERTY / JIS.
enum ProductKeyboardProfile {
  qwerty,
  qwertz,
  azerty,
  jis;

  /// Short Segment label.
  String get segmentLabel => imeProfile.segmentLabel;

  /// Full operator-facing name (same as Segment for these four).
  String get displayName => imeProfile.displayName;

  /// Value written as `profile=` in keyboard.conf (only the four soft ids).
  String get confProfileId => imeProfile.confId;

  CyberImeRegionalProfile get imeProfile => switch (this) {
        ProductKeyboardProfile.qwerty => CyberImeRegionalProfile.qwerty,
        ProductKeyboardProfile.qwertz => CyberImeRegionalProfile.qwertz,
        ProductKeyboardProfile.azerty => CyberImeRegionalProfile.azerty,
        ProductKeyboardProfile.jis => CyberImeRegionalProfile.jis,
      };

  /// XKB layout persisted in `keyboard.conf` (+ soft `profile=`).
  KeyboardLayout get xkbLayout => switch (this) {
        ProductKeyboardProfile.qwerty => KeyboardLayout(
            id: 'us',
            model: 'pc105',
            displayName: displayName,
            softProfile: confProfileId,
          ),
        ProductKeyboardProfile.qwertz => KeyboardLayout(
            id: 'de',
            model: 'pc105',
            displayName: displayName,
            softProfile: confProfileId,
          ),
        ProductKeyboardProfile.azerty => KeyboardLayout(
            id: 'fr',
            model: 'pc105',
            displayName: displayName,
            softProfile: confProfileId,
          ),
        ProductKeyboardProfile.jis => KeyboardLayout(
            id: 'jp',
            model: 'jp106',
            displayName: displayName,
            softProfile: confProfileId,
          ),
      };

  static ProductKeyboardProfile fromConfProfile(String profile) {
    return switch (CyberImeRegionalProfile.parse(profile)) {
      CyberImeRegionalProfile.qwerty => ProductKeyboardProfile.qwerty,
      CyberImeRegionalProfile.qwertz => ProductKeyboardProfile.qwertz,
      CyberImeRegionalProfile.azerty => ProductKeyboardProfile.azerty,
      CyberImeRegionalProfile.jis => ProductKeyboardProfile.jis,
    };
  }

  /// Map HAL / conf → product profile (prefer `profile=`, else XKB id).
  static ProductKeyboardProfile fromLayout(KeyboardLayout layout) {
    if (layout.softProfile.trim().isNotEmpty) {
      return fromConfProfile(layout.softProfile);
    }
    return fromConfProfile(layout.id.split(',').first);
  }

  static ProductKeyboardProfile fromXkbId(String id) =>
      fromLayout(KeyboardLayout(id: id));
}
