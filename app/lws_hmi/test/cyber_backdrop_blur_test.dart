import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// App keeps a smoke import; full coverage lives in packages/cyber_ui/test.
void main() {
  test('cyber_ui path dependency exports blur intensity', () {
    expect(CyberBlurIntensity.extreme.sigma, 25);
  });
}
