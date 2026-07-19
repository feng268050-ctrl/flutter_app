/// Clamp UI / platform percent values to the shared 0–100 contract.
int clampPercent(int value) => value.clamp(0, 100);

/// Hardware floor as percent of [max_brightness] when logical brightness is 0.
///
/// Logical API/UI stay 0–100; this only remaps onto usable PWM (never sysfs 0).
const int kBacklightHwFloorPercent = 5;

/// Minimum sysfs brightness for [max] (at least 1 when [max] ≥ 1).
int backlightHwFloorDevice(int max) {
  if (max <= 0) {
    return 0;
  }
  final floor =
      ((kBacklightHwFloorPercent / 100.0) * max).round().clamp(1, max);
  return floor;
}

/// Map 0–100 percent onto a device scale `[0, max]` (inclusive).
int percentToDevice(int percent, int max) {
  if (max <= 0) {
    return 0;
  }
  return ((clampPercent(percent) / 100.0) * max).round().clamp(0, max);
}

/// Map logical backlight percent onto `[hwFloor, max]` (never absolute 0).
int backlightPercentToDevice(int percent, int max) {
  if (max <= 0) {
    return 0;
  }
  final pct = clampPercent(percent);
  final floor = backlightHwFloorDevice(max);
  if (max <= floor) {
    return floor;
  }
  return (floor + ((pct / 100.0) * (max - floor)).round()).clamp(floor, max);
}

/// Reverse of [backlightPercentToDevice]: hardware floor → logical 0.
int backlightDeviceToPercent(int value, int max) {
  if (max <= 0) {
    return 0;
  }
  final floor = backlightHwFloorDevice(max);
  final v = value.clamp(0, max);
  if (v <= floor) {
    return 0;
  }
  if (max <= floor) {
    return 0;
  }
  return (((v - floor) / (max - floor)) * 100).round().clamp(0, 100);
}

/// Map a device scale value back to 0–100 percent (linear 0–max, no HW floor).
int deviceToPercent(int value, int max) {
  if (max <= 0) {
    return 0;
  }
  return ((value.clamp(0, max) / max) * 100).round().clamp(0, 100);
}
