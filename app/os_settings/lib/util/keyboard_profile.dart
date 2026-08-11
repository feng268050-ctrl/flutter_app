import 'package:cyber_hal/input/keyboard.dart';
import 'package:cyber_ime/cyber_ime.dart';

/// Soft keyboard Segment profiles (same three as HMI product keyboard).
enum KeyboardProfile {
  qwerty,
  qwertz,
  azerty;

  String get segmentLabel => imeProfile.segmentLabel;

  CyberImeRegionalProfile get imeProfile => switch (this) {
        KeyboardProfile.qwerty => CyberImeRegionalProfile.qwerty,
        KeyboardProfile.qwertz => CyberImeRegionalProfile.qwertz,
        KeyboardProfile.azerty => CyberImeRegionalProfile.azerty,
      };

  KeyboardLayout get xkbLayout => switch (this) {
        KeyboardProfile.qwerty => KeyboardLayout(
            id: 'us',
            model: 'pc105',
            displayName: 'QWERTY',
            softProfile: imeProfile.confId,
          ),
        KeyboardProfile.qwertz => KeyboardLayout(
            id: 'de',
            model: 'pc105',
            displayName: 'QWERTZ',
            softProfile: imeProfile.confId,
          ),
        KeyboardProfile.azerty => KeyboardLayout(
            id: 'fr',
            model: 'pc105',
            displayName: 'AZERTY',
            softProfile: imeProfile.confId,
          ),
      };

  static KeyboardProfile fromConfProfile(String profile) {
    return switch (CyberImeRegionalProfile.parse(profile)) {
      CyberImeRegionalProfile.qwerty => KeyboardProfile.qwerty,
      CyberImeRegionalProfile.qwertz => KeyboardProfile.qwertz,
      CyberImeRegionalProfile.azerty => KeyboardProfile.azerty,
    };
  }

  static KeyboardProfile fromLayout(KeyboardLayout layout) {
    if (layout.softProfile.trim().isNotEmpty) {
      return fromConfProfile(layout.softProfile);
    }
    return fromConfProfile(layout.id.split(',').first);
  }
}
