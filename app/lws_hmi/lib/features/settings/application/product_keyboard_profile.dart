import 'package:cyber_hal/input/keyboard.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// Product keyboard specification (Settings Segment + CyberIME + XKB).
///
/// Soft Segment labels: QWERTY / QWERTZ / AZERTY.
enum ProductKeyboardProfile {
  qwerty,
  qwertz,
  azerty;

  /// Short Segment label.
  String get segmentLabel => imeProfile.segmentLabel;

  /// Full operator-facing name (same as Segment for these three).
  String get displayName => imeProfile.displayName;

  /// Value written as `profile=` in keyboard.conf (only the three soft ids).
  String get confProfileId => imeProfile.confId;

  CyberImeRegionalProfile get imeProfile => switch (this) {
        ProductKeyboardProfile.qwerty => CyberImeRegionalProfile.qwerty,
        ProductKeyboardProfile.qwertz => CyberImeRegionalProfile.qwertz,
        ProductKeyboardProfile.azerty => CyberImeRegionalProfile.azerty,
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
      };

  static ProductKeyboardProfile fromConfProfile(String profile) {
    return switch (CyberImeRegionalProfile.parse(profile)) {
      CyberImeRegionalProfile.qwerty => ProductKeyboardProfile.qwerty,
      CyberImeRegionalProfile.qwertz => ProductKeyboardProfile.qwertz,
      CyberImeRegionalProfile.azerty => ProductKeyboardProfile.azerty,
    };
  }

  /// Map HAL / conf → product profile (prefer `profile=`, else XKB id).
  ///
  /// Legacy `jis` / `jp` migrate to QWERTY via [CyberImeRegionalProfile.parse].
  static ProductKeyboardProfile fromLayout(KeyboardLayout layout) {
    if (layout.softProfile.trim().isNotEmpty) {
      return fromConfProfile(layout.softProfile);
    }
    return fromConfProfile(layout.id.split(',').first);
  }

  static ProductKeyboardProfile fromXkbId(String id) =>
      fromLayout(KeyboardLayout(id: id));
}
