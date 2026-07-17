/// Product display orientation (maps to flutter-pi `-o` on Linux).
enum DisplayOrientationMode {
  landscape,
  portrait,
}

/// Persist + apply portrait/landscape (Linux: preference file + HMI restart).
abstract class DisplayOrientationController {
  Future<DisplayOrientationMode> getPreferred();

  /// Persist [mode] and apply (may restart the HMI process on Linux).
  Future<void> setPreferred(DisplayOrientationMode mode);

  Future<void> dispose();
}

/// Map product mode ↔ flutter-pi `-o` argument and preference file token.
class DisplayOrientationMapping {
  static const preferencePath = '/var/lib/hmi/display-orientation';

  static String toPreferenceToken(DisplayOrientationMode mode) {
    switch (mode) {
      case DisplayOrientationMode.landscape:
        return 'landscape';
      case DisplayOrientationMode.portrait:
        return 'portrait';
    }
  }

  static DisplayOrientationMode fromPreferenceToken(String? raw) {
    final token = (raw ?? '').trim().toLowerCase();
    if (token == 'portrait') {
      return DisplayOrientationMode.portrait;
    }
    return DisplayOrientationMode.landscape;
  }

  static String toFlutterPiFlag(DisplayOrientationMode mode) {
    switch (mode) {
      case DisplayOrientationMode.landscape:
        return 'landscape_left';
      case DisplayOrientationMode.portrait:
        return 'portrait_up';
    }
  }
}
