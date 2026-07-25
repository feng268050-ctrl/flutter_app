/// Mouse presence + settings via `mouse.conf` (HAL write; optional helper).
///
/// Concrete Linux type: [LinuxMouseSettingsController] (exported from `hal/input.dart`).
library;

export 'package:cyber_hal/src/input/mouse_settings.dart';
export 'package:cyber_hal/src/input/usb_hid_mouse_probe.dart';

import 'package:cyber_hal/src/input/mouse_settings.dart';

/// Settings-only API (migration / Demo injection).
abstract class MouseSettingsController {
  Future<MouseSettings> getSettings();

  /// Persist [settings] (Linux: write prefs; helper/compositor apply).
  Future<void> setSettings(MouseSettings settings);

  Future<void> dispose();
}

/// Portable mouse API: HID presence + preference get/set.
abstract class Mouse implements MouseSettingsController {
  Future<bool> isPresent();
}
