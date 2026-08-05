import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_eth0_path.dart';

void main() {
  test('planner avoids camera and same-subnet wlan host octets', () {
    expect(
      IpCameraEth0AddressPlanner.pickTabletEth0Address(
        '192.168.1.100',
        '192.168.1.234',
      ),
      '192.168.1.253',
    );
    expect(
      IpCameraEth0AddressPlanner.pickTabletEth0Address(
        '192.168.1.100',
        '10.0.0.5',
      ),
      '192.168.1.234',
    );
  });

  test('empty camera host is rejected', () {
    expect(
      () => IpCameraEth0AddressPlanner.pickTabletEth0Address('', null),
      throwsArgumentError,
    );
  });
}
