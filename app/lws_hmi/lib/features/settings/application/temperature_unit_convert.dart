import 'package:cyber_hal/locale.dart';

/// Advanced Settings temperature display helpers (lws-ui `TemperatureUnitConvertUtil`).
///
/// Device / Modbus values stay in **Celsius**. UI shows Fahrenheit when
/// Common Settings unit is Imperial.
abstract final class TemperatureUnitConvert {
  static bool isMetric(String? unitWire) =>
      unitWire == null || unitWire == UnitSystem.metric.wire;

  static int celsiusToFahrenheit(int celsius) =>
      (celsius * 9 / 5 + 32).round();

  static double celsiusToFahrenheitDouble(double celsius) =>
      celsius * 9 / 5 + 32;

  static int fahrenheitToCelsius(int fahrenheit) =>
      ((fahrenheit - 32) * 5 / 9).round();

  /// Value-box text (no unit suffix) for a Celsius store value.
  static String toDisplay(int celsius, String? unitWire) {
    if (isMetric(unitWire)) return '$celsius';
    return '${celsiusToFahrenheit(celsius)}';
  }

  /// Live sensor value with unit suffix (one decimal; lws-ui `formatSensorCelsius`).
  static String formatSensorCelsius(double celsius, String? unitWire) {
    if (isMetric(unitWire)) {
      return '${celsius.toStringAsFixed(1)} °C';
    }
    return '${celsiusToFahrenheitDouble(celsius).toStringAsFixed(1)} °F';
  }

  /// Slider scale endpoint label with unit suffix.
  static String formatScaleLabel(
    int celsius,
    String? unitWire, {
    required String celsiusUnit,
    required String fahrenheitUnit,
  }) {
    if (isMetric(unitWire)) return '$celsius$celsiusUnit';
    return '${celsiusToFahrenheit(celsius)}$fahrenheitUnit';
  }

  /// Parse dialog input (display unit) → Celsius for persistence.
  static int parseInputToCelsius(String input, String? unitWire) {
    final value = int.parse(input.trim());
    if (isMetric(unitWire)) return value;
    return fahrenheitToCelsius(value);
  }

  /// Display-unit bounds for a Celsius [min]/[max] range.
  static (int min, int max) displayRange(
    int minCelsius,
    int maxCelsius,
    String? unitWire,
  ) {
    if (isMetric(unitWire)) return (minCelsius, maxCelsius);
    return (
      celsiusToFahrenheit(minCelsius),
      celsiusToFahrenheit(maxCelsius),
    );
  }
}
