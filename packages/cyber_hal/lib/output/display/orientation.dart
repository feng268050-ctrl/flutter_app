/// Panel orientation preference (landscape / portrait).
///
/// Backend kind: OS preference + board helper (`change-orientation`) + HMI
/// restart to apply. Concrete Linux type: [LinuxOrientation] (exported from
/// `hal/output/display.dart`).
///
/// **Import note:** Flutter's `package:flutter/widgets.dart` also defines
/// `Orientation` (portrait/landscape for layout). Prefer:
/// `import 'package:cyber_hal/output/display/orientation.dart' as hal;`
/// when both are in scope, or import Flutter widgets with a prefix.
library;

/// Discrete panel orientation modes (wire tokens: `landscape` / `portrait`).
enum OrientationMode {
  landscape,
  portrait;

  /// Wire / prefs token (stable across locales).
  String get wireName => switch (this) {
        OrientationMode.landscape => 'landscape',
        OrientationMode.portrait => 'portrait',
      };

  static OrientationMode parse(
    String? raw, {
    OrientationMode fallback = OrientationMode.landscape,
  }) {
    final t = raw?.trim().toLowerCase();
    return switch (t) {
      'portrait' || 'portrait_up' => OrientationMode.portrait,
      'landscape' || 'landscape_left' || 'landscape_right' || '' || null =>
        OrientationMode.landscape,
      _ => fallback,
    };
  }
}

/// Portable panel orientation API.
///
/// Named [Orientation] per HAL design. Apps that also import Flutter widgets
/// should prefix this library import to avoid clashing with Flutter's
/// `Orientation`.
abstract class Orientation {
  Future<OrientationMode> getPreferred();

  /// Persist and apply (may restart HMI on Linux).
  Future<void> setPreferred(OrientationMode mode, {bool apply = true});

  Future<void> dispose();
}
