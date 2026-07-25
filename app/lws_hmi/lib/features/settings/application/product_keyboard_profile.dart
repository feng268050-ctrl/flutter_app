import 'package:cyber_hal/input/keyboard.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// Product keyboard specification (Settings Segment + CyberIME + XKB).
///
/// Segment labels: Default / QWERTY / QWERTZ / AZERTY / JIS.
enum ProductKeyboardProfile {
  defaultSoft,
  ansi,
  qwertz,
  azerty,
  jis;

  /// Short Segment label.
  String get segmentLabel => imeProfile.segmentLabel;

  /// Full operator-facing name (same as Segment for these five).
  String get displayName => imeProfile.displayName;

  /// Value written as `profile=` in keyboard.conf.
  String get confProfileId => switch (this) {
        ProductKeyboardProfile.defaultSoft => 'default',
        ProductKeyboardProfile.ansi => 'ansi',
        ProductKeyboardProfile.qwertz => 'qwertz',
        ProductKeyboardProfile.azerty => 'azerty',
        ProductKeyboardProfile.jis => 'jis',
      };

  CyberImeRegionalProfile get imeProfile => switch (this) {
        ProductKeyboardProfile.defaultSoft =>
          CyberImeRegionalProfile.defaultSoft,
        ProductKeyboardProfile.ansi => CyberImeRegionalProfile.ansi,
        ProductKeyboardProfile.qwertz => CyberImeRegionalProfile.qwertz,
        ProductKeyboardProfile.azerty => CyberImeRegionalProfile.azerty,
        ProductKeyboardProfile.jis => CyberImeRegionalProfile.jis,
      };

  /// XKB layout persisted in `keyboard.conf` (+ soft `profile=`).
  KeyboardLayout get xkbLayout => switch (this) {
        ProductKeyboardProfile.defaultSoft => KeyboardLayout(
            id: 'us',
            model: 'pc105',
            displayName: displayName,
            softProfile: confProfileId,
          ),
        ProductKeyboardProfile.ansi => KeyboardLayout(
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
    return switch (profile.trim().toLowerCase()) {
      'default' => ProductKeyboardProfile.defaultSoft,
      'ansi' => ProductKeyboardProfile.ansi,
      'qwertz' || 'de' => ProductKeyboardProfile.qwertz,
      'azerty' || 'fr' => ProductKeyboardProfile.azerty,
      'jis' || 'jp' => ProductKeyboardProfile.jis,
      _ => ProductKeyboardProfile.defaultSoft,
    };
  }

  /// Map HAL / conf → product profile (prefer `profile=`, else XKB id).
  static ProductKeyboardProfile fromLayout(KeyboardLayout layout) {
    if (layout.softProfile.trim().isNotEmpty) {
      return fromConfProfile(layout.softProfile);
    }
    final primary = layout.id.split(',').first.trim().toLowerCase();
    return switch (primary) {
      'de' => ProductKeyboardProfile.qwertz,
      'fr' => ProductKeyboardProfile.azerty,
      'jp' => ProductKeyboardProfile.jis,
      'us' => ProductKeyboardProfile.ansi,
      _ => ProductKeyboardProfile.defaultSoft,
    };
  }

  static ProductKeyboardProfile fromXkbId(String id) =>
      fromLayout(KeyboardLayout(id: id));
}
