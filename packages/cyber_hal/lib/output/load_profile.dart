/// SoC load / thermal profile (performance vs balanced).
///
/// Persist: `/var/lib/hal/power.conf` (`mode=`). Linux apply: board helper
/// `set-power-mode` / `set-performance-mode`. Concrete type: [LinuxLoadProfile].
library;

/// Discrete load / thermal profiles (wire tokens: `performance` / `balanced`).
enum LoadProfileMode {
  performance,
  balanced;

  /// Wire / prefs token (stable across locales).
  String get wireName => name;

  static LoadProfileMode parse(
    String? raw, {
    LoadProfileMode fallback = LoadProfileMode.performance,
  }) {
    final t = raw?.trim().toLowerCase();
    return switch (t) {
      'balanced' => LoadProfileMode.balanced,
      'performance' || '' || null => LoadProfileMode.performance,
      _ => fallback,
    };
  }
}

/// Portable SoC load / thermal profile API.
abstract class LoadProfile {
  /// Effective mode (`performance` when conf missing / invalid).
  Future<LoadProfileMode> getMode();

  /// Persist and apply hardware profile (Linux: board helper).
  Future<void> setMode(LoadProfileMode mode);

  Future<void> dispose();
}
