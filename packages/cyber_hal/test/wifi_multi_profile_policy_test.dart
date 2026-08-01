import 'package:cyber_hal/network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiMultiProfilePolicy', () {
    test('restores other enabled SSIDs, skips target and disabled', () {
      final keep = WifiMultiProfilePolicy.siblingPathsToRestore(
        before: const [
          (path: '/net/0', ssid: 'Home', enabled: true),
          (path: '/net/1', ssid: 'Office', enabled: true),
          (path: '/net/2', ssid: 'Guest', enabled: false),
        ],
        connectingSsid: 'Office',
      );
      expect(keep, {'/net/0'});
    });

    test('empty when nothing else auto-joins', () {
      final keep = WifiMultiProfilePolicy.siblingPathsToRestore(
        before: const [
          (path: '/net/1', ssid: 'Only', enabled: true),
        ],
        connectingSsid: 'Only',
      );
      expect(keep, isEmpty);
    });
  });
}
