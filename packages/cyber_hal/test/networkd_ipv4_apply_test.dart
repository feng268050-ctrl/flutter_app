import 'package:cyber_hal/src/network/networkd_ipv4_apply.dart';
import 'package:flutter_test/flutter_test.dart';

/// Render contract shared with overlay `networkd-apply-ipv4.sh` (boot restore).
/// If you change metrics / Domains=~. / DHCP blocks here, update the shell too.
void main() {
  group('NetworkdIpv4Apply.renderNetworkFile', () {
    test('dhcp includes RouteMetric', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'wlan0',
        mode: 'dhcp',
        routeMetric: 100,
      );
      expect(body, contains('Name=wlan0'));
      expect(body, contains('DHCP=yes'));
      expect(body, contains('IPv6AcceptRA=no'));
      expect(body, contains('[DHCPv4]'));
      expect(body, contains('UseDNS=yes'));
      expect(body, contains('RouteMetric=100'));
      expect(body, contains('Domains=~.'));
      expect(body, isNot(contains('Gateway=')));
    });

    test('ethernet dhcp does not claim Domains=~.', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'eth0',
        mode: 'dhcp',
        routeMetric: 2000,
      );
      expect(body, contains('RouteMetric=2000'));
      expect(body, contains('UseDNS=yes'));
      expect(body, isNot(contains('Domains=~.')));
    });

    test('static uses [Route] Metric', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'eth0',
        mode: 'static',
        routeMetric: 2000,
        address: '192.168.1.10',
        prefix: '24',
        gateway: '192.168.1.1',
        dns: '8.8.8.8',
      );
      expect(body, contains('Address=192.168.1.10/24'));
      expect(body, contains('DHCP=no'));
      expect(body, contains('IPv6AcceptRA=no'));
      expect(body, contains('LinkLocalAddressing=no'));
      expect(body, isNot(contains('LinkLocalAddressing=ipv4')));
      expect(body, contains('DNS=8.8.8.8'));
      expect(body, isNot(contains('Domains=~.')));
      expect(body, contains('[Route]'));
      expect(body, contains('Gateway=192.168.1.1'));
      expect(body, contains('Metric=2000'));
    });

    test('wifi static claims Domains=~.', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'wlan0',
        mode: 'static',
        routeMetric: 100,
        address: '10.0.0.2',
        prefix: '24',
        gateway: '10.0.0.1',
        dns: '10.0.0.1',
      );
      expect(body, contains('Domains=~.'));
      expect(body, contains('DNS=10.0.0.1'));
    });

    test('dhcp manual dns uses UseDNS=no', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'wlan0',
        mode: 'dhcp',
        routeMetric: 100,
        dns: '1.1.1.1 8.8.8.8',
      );
      expect(body, contains('DHCP=yes'));
      expect(body, contains('DNS=1.1.1.1 8.8.8.8'));
      expect(body, contains('UseDNS=no'));
      expect(body, isNot(contains('UseDNS=yes')));
      expect(body, contains('Domains=~.'));
    });

    test('dhcp automatic dns keeps UseDNS=yes', () {
      final body = NetworkdIpv4Apply.renderNetworkFile(
        iface: 'wlan0',
        mode: 'dhcp',
        routeMetric: 100,
      );
      expect(body, contains('UseDNS=yes'));
      expect(body, isNot(contains('\nDNS=')));
    });

    test('defaultRouteMetric prefers wifi', () {
      expect(NetworkdIpv4Apply.defaultRouteMetric('wlan0'), 100);
      expect(NetworkdIpv4Apply.defaultRouteMetric('eth0'), 2000);
      expect(NetworkdIpv4Apply.dnsDefaultRoutePreferred(100), isTrue);
      expect(NetworkdIpv4Apply.dnsDefaultRoutePreferred(2000), isFalse);
      expect(
        NetworkdIpv4Apply.defaultRouteMetric('wlan0') <
            NetworkdIpv4Apply.defaultRouteMetric('eth0'),
        isTrue,
      );
    });
  });
}
