/// Reusable backlight brightness API (Linux sysfs now; Android later).
abstract class BacklightController {
  Future<int> getBrightnessPercent();

  Future<void> setBrightnessPercent(int percent);

  Future<void> dispose();
}
