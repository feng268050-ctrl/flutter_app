import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_hal/locale.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';

void main() {
  test('metric uses mm suffix and raw millimetre labels', () {
    expect(LengthUnitConvert.isMetric(UnitSystem.metric.wire), isTrue);
    expect(LengthUnitConvert.suffix(UnitSystem.metric.wire), 'mm');
    expect(
      LengthUnitConvert.formatMm(1.5, unitWire: UnitSystem.metric.wire),
      '1.5',
    );
  });

  test('imperial uses in suffix and mm/25 labels', () {
    expect(
      LengthUnitConvert.isMetric(UnitSystem.imperial.wire),
      isFalse,
    );
    expect(LengthUnitConvert.suffix(UnitSystem.imperial.wire), 'in');
    expect(
      LengthUnitConvert.formatMm(25, unitWire: UnitSystem.imperial.wire),
      '1',
    );
    expect(
      LengthUnitConvert.formatMm(12.5,
          unitWire: UnitSystem.imperial.wire),
      '0.5',
    );
  });
}
