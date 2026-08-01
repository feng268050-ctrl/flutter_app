import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiApList.partitionMyAndOther', () {
    test('saved appears in my, unsaved scan in other', () {
      const saved = [
        WifiSavedNetwork(networkId: 0, ssid: 'Home', autoJoin: true),
      ];
      const scanned = [
        WifiAccessPoint(ssid: 'Home', signalDbm: -50, flags: '[WPA2-PSK]'),
        WifiAccessPoint(ssid: 'Cafe', signalDbm: -60, flags: '[WPA2-PSK]'),
      ];
      final parts = WifiApList.partitionMyAndOther(
        saved: saved,
        scanned: scanned,
        connectedSsid: 'Home',
      );
      expect(parts.myNetworks.map((a) => a.ssid), ['Home']);
      expect(parts.myNetworks.first.signalDbm, -50);
      expect(parts.otherNetworks.map((a) => a.ssid), ['Cafe']);
    });

    test('saved excluded from other even when scanned', () {
      const saved = [
        WifiSavedNetwork(networkId: 1, ssid: 'Office'),
      ];
      const scanned = [
        WifiAccessPoint(ssid: 'Office', signalDbm: -40),
        WifiAccessPoint(ssid: 'Guest', signalDbm: -70),
      ];
      final parts = WifiApList.partitionMyAndOther(
        saved: saved,
        scanned: scanned,
      );
      expect(parts.otherNetworks.map((a) => a.ssid), ['Guest']);
    });

    test('offline saved still listed under my networks', () {
      const saved = [
        WifiSavedNetwork(networkId: 2, ssid: 'HiddenHome', autoJoin: false),
      ];
      final parts = WifiApList.partitionMyAndOther(
        saved: saved,
        scanned: const [],
      );
      expect(parts.myNetworks.map((a) => a.ssid), ['HiddenHome']);
      expect(parts.myNetworks.first.secured, isTrue);
      expect(parts.otherNetworks, isEmpty);
    });
  });

  group('WifiSavedNetwork autoJoin', () {
    test('defaults to true', () {
      const n = WifiSavedNetwork(networkId: 0, ssid: 'A');
      expect(n.autoJoin, isTrue);
    });
  });
}
