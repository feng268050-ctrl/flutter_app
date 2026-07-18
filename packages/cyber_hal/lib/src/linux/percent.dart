/// Clamp UI / platform percent values to the shared 0–100 contract.
int clampPercent(int value) => value.clamp(0, 100);

/// Map 0–100 percent onto a device scale `[0, max]` (inclusive).
int percentToDevice(int percent, int max) {
  if (max <= 0) {
    return 0;
  }
  return ((clampPercent(percent) / 100.0) * max).round().clamp(0, max);
}

/// Map a device scale value back to 0–100 percent.
int deviceToPercent(int value, int max) {
  if (max <= 0) {
    return 0;
  }
  return ((value.clamp(0, max) / max) * 100).round().clamp(0, 100);
}
