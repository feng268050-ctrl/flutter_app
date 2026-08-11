import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_hal/src/output/display/linux_ui_scale.dart';

void main() {
  test('clampScale defaults invalid to 1.0', () {
    expect(LinuxUiScale.clampScale(double.nan), 1.0);
    expect(LinuxUiScale.clampScale(1.0), 1.0);
    expect(LinuxUiScale.clampScale(0.5), LinuxUiScale.minScale);
    expect(LinuxUiScale.clampScale(2.0), LinuxUiScale.maxScale);
  });
}
