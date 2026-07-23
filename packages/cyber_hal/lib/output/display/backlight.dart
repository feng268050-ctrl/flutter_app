/// Backlight / brightness (sysfs + preference path).
///
/// Backend kind: device/sysfs (+ optional board helper).
/// Concrete Linux type: [LinuxSysfsBacklight] (exported from `hal/output.dart`).
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
abstract class Backlight {
  Future<int> getBrightnessPercent();

  Future<void> setBrightnessPercent(int percent);

  Future<void> dispose();
}

/// Migration alias — prefer [Backlight].
typedef BacklightController = Backlight;
