import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';

void main() {
  test('metric uses mm suffix and raw millimetre labels', () {
    expect(LengthUnitConvert.isMetric(CommonSettingsStore.unitMetric), isTrue);
    expect(LengthUnitConvert.suffix(CommonSettingsStore.unitMetric), 'mm');
    expect(
      LengthUnitConvert.formatMm(1.5, unitWire: CommonSettingsStore.unitMetric),
      '1.5',
    );
  });

  test('imperial uses in suffix and mm/25 labels', () {
    expect(
      LengthUnitConvert.isMetric(CommonSettingsStore.unitImperial),
      isFalse,
    );
    expect(LengthUnitConvert.suffix(CommonSettingsStore.unitImperial), 'in');
    expect(
      LengthUnitConvert.formatMm(25, unitWire: CommonSettingsStore.unitImperial),
      '1',
    );
    expect(
      LengthUnitConvert.formatMm(12.5,
          unitWire: CommonSettingsStore.unitImperial),
      '0.5',
    );
  });
}
