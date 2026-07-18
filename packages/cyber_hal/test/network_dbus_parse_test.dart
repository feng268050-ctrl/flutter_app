import 'package:cyber_hal/src/network/networkd_dbus.dart';
import 'package:cyber_hal/src/network/wpa_supplicant_dbus.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseNetworkdAddresses extracts IPv4', () {
    final value = DBusArray(
      DBusSignature('(iiay)'),
      [
        DBusStruct([
          DBusInt32(2), // AF_INET
          DBusInt32(24),
          DBusArray.byte([192, 168, 1, 10]),
        ]),
      ],
    );
    final addrs = parseNetworkdAddresses(value);
    expect(addrs, hasLength(1));
    expect(addrs.first.address, '192.168.1.10');
    expect(addrs.first.prefix, 24);
  });

  test('parseNetworkdDescribeJson extracts IPv4 gateway DNS', () {
    const json = '''
{
  "OperationalState": "routable",
  "Addresses": [
    {"Family": 10, "Address": [254,128,0,0,0,0,0,0,1,2,3,4,5,6,7,8], "PrefixLength": 64},
    {"Family": 2, "Address": [10,0,2,22], "PrefixLength": 24}
  ],
  "Routes": [
    {"Family": 2, "DestinationPrefixLength": 24, "Gateway": [10,0,2,1]},
    {"Family": 2, "DestinationPrefixLength": 0, "Gateway": [10,0,2,1]}
  ],
  "DNS": [
    {"Family": 2, "Address": [8,8,8,8]}
  ]
}
''';
    final snap = parseNetworkdDescribeJson(json);
    expect(snap.operational, 'routable');
    expect(snap.primaryIpv4, '10.0.2.22');
    expect(snap.primaryPrefix, 24);
    expect(snap.gateway, '10.0.2.1');
    expect(snap.dns, '8.8.8.8');
  });

  test('WpaIfaceSnapshot maps completed state', () {
    const snap = WpaIfaceSnapshot(state: 'completed');
    expect(snap.wpaStateToken, 'COMPLETED');
  });
}
