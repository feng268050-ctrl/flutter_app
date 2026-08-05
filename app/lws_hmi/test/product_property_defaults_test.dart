import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/device/product_property_defaults.dart';

void main() {
  test('product property defaults when blank', () {
    expect(effectiveCameraIp(null), kDefaultCameraIp);
    expect(effectiveCameraIp(''), kDefaultCameraIp);
    expect(effectiveCameraIp(' 10.0.0.5 '), '10.0.0.5');
    expect(effectiveCameraType(null), kDefaultCameraType);
    expect(typedCameraType('9'), isEmpty);
    expect(typedCameraType('2'), '2');
    expect(effectiveFocusScaleRef(''), kDefaultFocusScaleRef);
    expect(effectiveFocusScaleRef('12'), '12');
    expect(
      effectiveControlCardCommAlarmMode(null),
      kDefaultControlCardCommAlarmMode,
    );
    expect(effectiveControlCardCommAlarmMode('immediate'), 'immediate');
    expect(effectiveControlCardCommAlarmMode('bogus'), isEmpty);
  });
}
