/// Backlight / brightness (sysfs + preference path).
///
/// Backend kind: device/sysfs (+ optional board helper).
/// Concrete Linux type: [LinuxSysfsBacklight] (exported from `hal/output.dart`).
library;

/// Portable backlight API (0–100 percent).
abstract class Backlight {
  Future<int> getBrightnessPercent();

  Future<void> setBrightnessPercent(int percent);

  Future<void> dispose();
}

/// Migration alias — prefer [Backlight].
typedef BacklightController = Backlight;
