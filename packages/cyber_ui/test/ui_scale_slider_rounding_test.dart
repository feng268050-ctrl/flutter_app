import 'package:cyber_ui/src/widgets/cyber_slider_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valueFromFraction preserves fractional ui_scale range', () {
    const min = 0.5;
    const max = 2.0;
    final values = <double>[];
    for (var i = 0; i <= 10; i++) {
      values.add(
        CyberSliderLogic.valueFromFraction(i / 10, min, max),
      );
    }
    expect(values.first, closeTo(min, 0.001));
    expect(values.last, closeTo(max, 0.001));
    expect(values.toSet().length, greaterThan(2));
  });

  test('valueFromFraction keeps integer steps for coarse sliders', () {
    expect(CyberSliderLogic.valueFromFraction(0.5, 0, 100), 50);
  });
}
