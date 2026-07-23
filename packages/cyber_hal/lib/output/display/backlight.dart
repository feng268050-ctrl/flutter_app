/// Backlight / brightness (sysfs + preference path).
///
/// Backend kind: device/sysfs (+ optional board helper).
/// Concrete Linux type: [LinuxSysfsBacklight] (exported from `hal/output/display.dart`).
library;

export 'package:cyber_hal/src/linux/percent.dart'
    show
        backlightDeviceToPercent,
        backlightPercentToDevice,
        kBacklightHwFloorPercent;

/// Portable backlight API (logical 0–100 percent).
///
/// Logical 0 means dimmest usable level; Linux backends remap onto a non-zero
/// hardware floor so the panel is never extinguished via absolute sysfs 0.
/// [AutoSleep] uses [setAbsoluteBrightness] / absolute `0` to power the panel off.
abstract class Backlight {
  Future<int> getBrightnessPercent();

  /// Apply and persist brightness (user preference).
  Future<void> setBrightnessPercent(int percent);

  /// Write a raw device brightness value without touching the preference file.
  ///
  /// Absolute `0` powers the panel off (AutoSleep blank). Other values are the
  /// remapped device units for the active backlight node.
  Future<void> setAbsoluteBrightness(int deviceValue);

  Future<void> dispose();
}

/// Migration alias — prefer [Backlight].
typedef BacklightController = Backlight;
