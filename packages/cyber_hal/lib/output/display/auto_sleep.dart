/// Auto-sleep / screen-off idle policy (absolute backlight off + double-tap wake).
///
/// Backend kind: OS component / App-armed idle watchdog (+ backlight).
/// Concrete Linux type: [LinuxAutoSleep] (exported from `hal/output/display.dart`).
library;

import 'package:cyber_hal/output/display/backlight.dart';

/// Discrete screen-off idle policies (Settings labels stay in the App).
enum AutoSleepPolicy {
  minutes10,
  minutes30,
  minutes60,
  never;

  /// Idle duration before blanking; `null` means never blank.
  Duration? get idleDuration => switch (this) {
        AutoSleepPolicy.minutes10 => const Duration(minutes: 10),
        AutoSleepPolicy.minutes30 => const Duration(minutes: 30),
        AutoSleepPolicy.minutes60 => const Duration(minutes: 60),
        AutoSleepPolicy.never => null,
      };

  /// Wire / prefs token (stable across locales).
  String get wireName => switch (this) {
        AutoSleepPolicy.minutes10 => '10',
        AutoSleepPolicy.minutes30 => '30',
        AutoSleepPolicy.minutes60 => '60',
        AutoSleepPolicy.never => 'never',
      };

  static AutoSleepPolicy parse(
    String? raw, {
    AutoSleepPolicy fallback = AutoSleepPolicy.never,
  }) {
    final t = raw?.trim().toLowerCase();
    return switch (t) {
      '10' || '10m' || '10min' || 'minutes10' => AutoSleepPolicy.minutes10,
      '30' || '30m' || '30min' || 'minutes30' => AutoSleepPolicy.minutes30,
      '60' || '60m' || '60min' || 'minutes60' => AutoSleepPolicy.minutes60,
      'never' || 'off' || '0' || '' || null => AutoSleepPolicy.never,
      _ => fallback,
    };
  }
}

/// Portable auto-sleep API.
abstract class AutoSleep {
  Future<AutoSleepPolicy> getPolicy();

  Future<void> setPolicy(AutoSleepPolicy policy);

  /// Whether the panel is currently powered off by this watchdog.
  bool get isBlanked;

  /// Arm idle monitoring against [backlight]. Idempotent.
  void arm({required Backlight backlight});

  /// While awake: reset idle timer. While blanked: feed double-tap wake detector.
  void noteActivity();

  Future<void> dispose();
}
