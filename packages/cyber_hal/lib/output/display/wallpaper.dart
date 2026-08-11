/// System wallpaper preference (shared across Weston + Flutter Apps).
///
/// Backend kind: OS preference file + packaged presets under
/// `/usr/share/hal/wallpapers` + active copy under `/var/lib/hal/`.
/// Concrete Linux type: [LinuxWallpaper] (exported from `hal/output/display.dart`).
///
/// Product / platform Apps select among packaged presets; selecting copies the
/// file next to `display.conf` and persists the absolute path so Weston
/// (`background-image`) and every Flutter seat paint the same image.
library;

import 'package:flutter/foundation.dart';

/// One packaged wallpaper preset.
final class WallpaperPreset {
  const WallpaperPreset({
    required this.id,
    required this.path,
    required this.label,
  });

  /// Basename without extension (stable wire id), e.g. `home_back`.
  final String id;

  /// Absolute path under the presets directory.
  final String path;

  /// Operator-facing label.
  final String label;
}

/// Portable system wallpaper API.
abstract class Wallpaper {
  /// Active absolute image path (empty when unset / unresolved).
  String get activePath;

  /// Selected preset id (`wallpaper_id` in display.conf), when known.
  String get activePresetId;

  /// Fires when [activePath] / [activePresetId] change after warm-read or
  /// [setPreset]. UI layers (shared σ bake) listen here — bake stays out of HAL.
  Listenable get listenable;

  /// Synchronous warm-read for App bootstrap.
  String warmRead();

  Future<String> getActivePath();

  /// Packaged presets under `/usr/share/hal/wallpapers` (sorted by id).
  Future<List<WallpaperPreset>> listPresets();

  /// Copy [presetId] to the active wallpaper file, persist path, optionally
  /// restart the UI seat so Weston reloads `background-image`.
  Future<void> setPreset(String presetId, {bool apply = true});

  Future<void> dispose();
}
