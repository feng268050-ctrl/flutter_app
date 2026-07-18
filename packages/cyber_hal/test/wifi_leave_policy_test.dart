import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiLeavePolicy', () {
    test('disconnect keeps saved networks and link up', () {
      expect(WifiLeavePolicy.removesSavedNetworks(WifiLeaveKind.disconnect), isFalse);
      expect(WifiLeavePolicy.keepsLinkUp(WifiLeaveKind.disconnect), isTrue);
      expect(WifiLeavePolicy.disablesCurrentNetwork(WifiLeaveKind.disconnect), isTrue);
    });

    test('forget removes matching SSID only', () {
      expect(WifiLeavePolicy.removesSavedNetworks(WifiLeaveKind.forget), isTrue);
      expect(WifiLeavePolicy.keepsLinkUp(WifiLeaveKind.forget), isTrue);
      expect(WifiLeavePolicy.disablesCurrentNetwork(WifiLeaveKind.forget), isFalse);

      const saved = [
        WifiSavedNetwork(networkId: 0, ssid: 'Home'),
        WifiSavedNetwork(networkId: 1, ssid: 'Cafe'),
        WifiSavedNetwork(networkId: 2, ssid: 'Home'),
      ];
      final remove = WifiLeavePolicy.networksToRemove(
        kind: WifiLeaveKind.forget,
        saved: saved,
        ssidOf: (n) => n.ssid,
        forgetSsid: 'Home',
      );
      expect(remove.map((n) => n.networkId), [0, 2]);

      expect(
        WifiLeavePolicy.networksToRemove(
          kind: WifiLeaveKind.disconnect,
          saved: saved,
          ssidOf: (n) => n.ssid,
          forgetSsid: 'Home',
        ),
        isEmpty,
      );
    });
  });
}
