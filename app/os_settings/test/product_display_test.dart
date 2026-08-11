import 'package:flutter_test/flutter_test.dart';
import 'package:os_settings/util/product_display.dart';

void main() {
  test('productDeviceModelDisplay joins brand and model', () {
    expect(productDeviceModelDisplay('Innohi', 'YNH960'), 'Innohi YNH960');
    expect(productDeviceModelDisplay(null, null), kUnavailableDisplay);
  });
}
