import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/temperature_unit_convert.dart';

void main() {
  test('metric display keeps Celsius', () {
    expect(
      TemperatureUnitConvert.toDisplay(80, CommonSettingsStore.unitMetric),
      '80',
    );
    expect(
      TemperatureUnitConvert.formatScaleLabel(
        80,
        CommonSettingsStore.unitMetric,
        celsiusUnit: '℃',
        fahrenheitUnit: '℉',
      ),
      '80℃',
    );
  });

  test('imperial display converts store Celsius to Fahrenheit', () {
    expect(
      TemperatureUnitConvert.toDisplay(0, CommonSettingsStore.unitImperial),
      '32',
    );
    expect(
      TemperatureUnitConvert.toDisplay(80, CommonSettingsStore.unitImperial),
      '176',
    );
    expect(
      TemperatureUnitConvert.parseInputToCelsius(
        '176',
        CommonSettingsStore.unitImperial,
      ),
      80,
    );
  });

  test('formatSensorCelsius follows Common Settings unit', () {
    expect(
      TemperatureUnitConvert.formatSensorCelsius(
        25.1,
        CommonSettingsStore.unitMetric,
      ),
      '25.1 °C',
    );
    expect(
      TemperatureUnitConvert.formatSensorCelsius(
        25.1,
        CommonSettingsStore.unitImperial,
      ),
      '77.2 °F',
    );
  });
}
