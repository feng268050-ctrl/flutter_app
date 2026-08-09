import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_hal/locale.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';

void main() {
  test('metric display keeps Celsius', () {
    expect(
      TemperatureUnitConvert.toDisplay(80, UnitSystem.metric.wire),
      '80',
    );
    expect(
      TemperatureUnitConvert.formatScaleLabel(
        80,
        UnitSystem.metric.wire,
        celsiusUnit: '℃',
        fahrenheitUnit: '℉',
      ),
      '80℃',
    );
  });

  test('imperial display converts store Celsius to Fahrenheit', () {
    expect(
      TemperatureUnitConvert.toDisplay(0, UnitSystem.imperial.wire),
      '32',
    );
    expect(
      TemperatureUnitConvert.toDisplay(80, UnitSystem.imperial.wire),
      '176',
    );
    expect(
      TemperatureUnitConvert.parseInputToCelsius(
        '176',
        UnitSystem.imperial.wire,
      ),
      80,
    );
  });

  test('formatSensorCelsius follows Common Settings unit', () {
    expect(
      TemperatureUnitConvert.formatSensorCelsius(
        25.1,
        UnitSystem.metric.wire,
      ),
      '25.1 °C',
    );
    expect(
      TemperatureUnitConvert.formatSensorCelsius(
        25.1,
        UnitSystem.imperial.wire,
      ),
      '77.2 °F',
    );
  });
}
