import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/device/device_identity_qr.dart';
import 'package:lws_hmi/device/display_value.dart';

void main() {
  test('productDeviceModelDisplay joins brand and model', () {
    expect(productDeviceModelDisplay('Innohi', 'YNH960'), 'Innohi YNH960');
  });

  test('productDeviceModelDisplay both empty is single dash', () {
    expect(productDeviceModelDisplay(null, null), kUnavailableDisplay);
    expect(productDeviceModelDisplay('', ''), kUnavailableDisplay);
    expect(productDeviceModelDisplay('  ', ' '), kUnavailableDisplay);
  });

  test('productDeviceModelDisplay one side missing uses dash part', () {
    expect(productDeviceModelDisplay('Innohi', null), 'Innohi -');
    expect(productDeviceModelDisplay(null, 'YNH960'), '- YNH960');
  });

  test('productDeviceModelForQr omits dash placeholders', () {
    expect(productDeviceModelForQr('Innohi', 'YNH960'), 'Innohi YNH960');
    expect(productDeviceModelForQr('Innohi', null), 'Innohi');
    expect(productDeviceModelForQr(null, 'YNH960'), 'YNH960');
    expect(productDeviceModelForQr(null, null), '');
  });

  test('productCameraTypeDisplay maps 1/2; empty defaults to Blue Light', () {
    expect(productCameraTypeDisplay('1'), 'Blue Light');
    expect(productCameraTypeDisplay('2'), 'Red Light');
    expect(productCameraTypeDisplay(null), 'Blue Light');
    expect(productCameraTypeDisplay(''), 'Blue Light');
    expect(productCameraTypeDisplay('  '), 'Blue Light');
    expect(productCameraTypeDisplay('9'), kUnavailableDisplay);
  });

  test('effectiveCameraType defaults empty to 1', () {
    expect(effectiveCameraType(null), kDefaultCameraType);
    expect(effectiveCameraType(''), kDefaultCameraType);
    expect(effectiveCameraType('2'), '2');
    expect(effectiveCameraType('9'), '9');
  });

  test('DeviceIdentityQr v2 payload matches lws-ui shape', () {
    expect(
      DeviceIdentityQr.contentV2(
        sn: 'ABC',
        model: 'Innohi YNH960',
        systemVersion: '1.0.38',
      ),
      'ABC|2|Innohi YNH960|1.0.38',
    );
    expect(
      DeviceIdentityQr.contentV2(
        sn: 'a|b',
        model: 'm|n',
        systemVersion: '1|0',
      ),
      'a_b|2|m_n|1_0',
    );
  });
}
