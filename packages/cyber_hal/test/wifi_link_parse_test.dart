import 'package:cyber_hal/src/network/wifi_link_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiLinkParse.ipv4PrefixToSubnetMask', () {
    test('maps common prefix lengths', () {
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(24), '255.255.255.0');
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(16), '255.255.0.0');
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(8), '255.0.0.0');
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(32), '255.255.255.255');
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(0), '0.0.0.0');
    });

    test('returns null for invalid input', () {
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(null), isNull);
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(-1), isNull);
      expect(WifiLinkParse.ipv4PrefixToSubnetMask(33), isNull);
    });
  });

  group('WifiLinkParse.linkSpeedMbpsFromIw', () {
    test('parses tx bitrate in MBit/s and GBit/s', () {
      expect(
        WifiLinkParse.linkSpeedMbpsFromIw(
          'Connected to aa:bb:cc:dd:ee:ff (on wlan0)\n'
          '\ttx bitrate: 72.2 MBit/s\n',
        ),
        72,
      );
      expect(
        WifiLinkParse.linkSpeedMbpsFromIw('\ttx bitrate: 1.2 GBit/s\n'),
        1200,
      );
    });

    test('returns null when bitrate is absent', () {
      expect(WifiLinkParse.linkSpeedMbpsFromIw('Not connected.'), isNull);
    });
  });
}
