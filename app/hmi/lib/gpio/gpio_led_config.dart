/// Side-panel RGB indicators on ynh960.
///
/// Match **original** lws-ui `GpioLedConfig` (pre-aca52502): red=5, yellow=4,
/// green=7 — the later 4/3/6 remap was wrong for gpio_innohi on this board.
/// Linux path: `/sys/class/gpio_innohi/GPIO_N/value` (Innohi `gpio_innohi`).
///
/// SoC lines (classic sysfs fallback; usually busy once gpio_innohi probed):
/// - Yellow → GPIO_4 → gpio3 RK_PB2 → linux 106
/// - Red    → GPIO_5 → gpio3 RK_PB1 → linux 105
/// - Green  → GPIO_7 → gpio4 RK_PC5 → linux 149
class GpioLedConfig {
  GpioLedConfig._();

  /// gpio_innohi / YNHAPI abstract indices (DTS labels GPIO_N).
  static const int yellowYnhApi = 4;
  static const int redYnhApi = 5;
  static const int greenYnhApi = 7;

  /// Linux global GPIO numbers (RK356x: gpio3=96..127, gpio4=128..159).
  static const int yellowLinuxGpio = 106; // gpio3 + RK_PB2 (8+2)
  static const int redLinuxGpio = 105; // gpio3 + RK_PB1 (8+1)
  static const int greenLinuxGpio = 149; // gpio4 + RK_PC5 (16+5)

  static const int flashOnMs = 1000;
  static const int flashOffMs = 1000;
}

enum LedColor {
  red(
    ynhApiPin: GpioLedConfig.redYnhApi,
    linuxGpio: GpioLedConfig.redLinuxGpio,
  ),
  yellow(
    ynhApiPin: GpioLedConfig.yellowYnhApi,
    linuxGpio: GpioLedConfig.yellowLinuxGpio,
  ),
  green(
    ynhApiPin: GpioLedConfig.greenYnhApi,
    linuxGpio: GpioLedConfig.greenLinuxGpio,
  );

  const LedColor({required this.ynhApiPin, required this.linuxGpio});

  /// Abstract index: `/sys/class/gpio_innohi/GPIO_N` and YNHAPI `setGpioState`.
  final int ynhApiPin;

  /// Linux sysfs / libgpiod line number for the same pad.
  final int linuxGpio;

  /// Prefer gpio_innohi label path; [linuxGpio] is fallback only.
  int get pin => ynhApiPin;
}

/// Modes aligned with lws-ui `IndicatorMode` (Steady / Blink / Off).
enum IndicatorMode {
  off,
  blink,
  steadyOn,
}
