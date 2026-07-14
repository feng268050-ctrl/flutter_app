/// lws-ui `GpioLedConfig` abstract pin numbers (YNHAPI / own-gpio indices).
class GpioLedConfig {
  GpioLedConfig._();

  static const int red = 4;
  static const int yellow = 3;
  static const int green = 6;

  static const int flashOnMs = 1000;
  static const int flashOffMs = 1000;
}

enum LedColor {
  red(GpioLedConfig.red),
  yellow(GpioLedConfig.yellow),
  green(GpioLedConfig.green);

  const LedColor(this.pin);

  final int pin;
}

/// Modes aligned with lws-ui `IndicatorMode` (Steady / Blink / Off).
enum IndicatorMode {
  off,
  blink,
  steadyOn,
}
