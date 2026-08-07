import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upsertCountryInConf replaces existing country', () {
    const conf = 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root\n'
        'update_config=1\n'
        'country=CN\n';
    final next = WifiCountryApply.upsertCountryInConf(conf, 'US');
    expect(next, contains('country=US'));
    expect(next, isNot(contains('country=CN')));
  });

  test('upsertCountryInConf inserts after update_config', () {
    const conf = 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root\n'
        'update_config=1\n';
    final next = WifiCountryApply.upsertCountryInConf(conf, 'DE');
    expect(next, contains('update_config=1\ncountry=DE'));
  });
}
