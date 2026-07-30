import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/status_bar/status_bar_phase.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

void main() {
  group('mapWifiStatusBarPhase', () {
    test('off → hidden', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.off,
          connection: WifiConnectionPhase.disconnected,
        ),
        CyberConnectivityIconPhase.hidden,
      );
    });

    test('starting → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.starting,
          connection: WifiConnectionPhase.disconnected,
        ),
        CyberConnectivityIconPhase.connecting,
      );
    });

    test('associating → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.associating,
        ),
        CyberConnectivityIconPhase.connecting,
      );
    });

    test('obtainingIp → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.obtainingIp,
        ),
        CyberConnectivityIconPhase.connecting,
      );
    });

    test('connected → connected', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.connected,
        ),
        CyberConnectivityIconPhase.connected,
      );
    });

    test('on + disconnected → onIdle', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.disconnected,
        ),
        CyberConnectivityIconPhase.onIdle,
      );
    });

    test('error + failed → onIdle (still visible)', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.error,
          connection: WifiConnectionPhase.failed,
        ),
        CyberConnectivityIconPhase.onIdle,
      );
    });
  });

  group('buildProductStatusIconItems cloud slot', () {
    test('cloud ahead of wifi only when wifi linked', () {
      final idle = buildProductStatusIconItems(
        wifiPhase: CyberConnectivityIconPhase.onIdle,
        bluetoothPhase: CyberConnectivityIconPhase.hidden,
        cameraStatus: CyberCameraLinkStatus.connecting,
      );
      expect(
        idle.any((w) => w.key == const ValueKey('home-status-cloud')),
        isFalse,
      );

      final linked = buildProductStatusIconItems(
        wifiPhase: CyberConnectivityIconPhase.connected,
        bluetoothPhase: CyberConnectivityIconPhase.hidden,
        cameraStatus: CyberCameraLinkStatus.connecting,
        cloudConnected: false,
      );
      expect(linked.first.key, const ValueKey('home-status-cloud'));
      expect(
        (linked.first as CyberCloudStatusIcon).linked,
        isFalse,
      );

      final online = buildProductStatusIconItems(
        wifiPhase: CyberConnectivityIconPhase.connected,
        bluetoothPhase: CyberConnectivityIconPhase.hidden,
        cameraStatus: CyberCameraLinkStatus.connecting,
        cloudConnected: true,
      );
      expect((online.first as CyberCloudStatusIcon).linked, isTrue);
    });
  });

  group('mapBluetoothStatusBarPhase', () {
    test('off → hidden', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.off,
          devices: const [],
        ),
        CyberConnectivityIconPhase.hidden,
      );
    });

    test('starting → connecting', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.starting,
          devices: const [],
        ),
        CyberConnectivityIconPhase.connecting,
      );
    });

    test('pairing challenge → connecting', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.on,
          devices: const [],
          pairingChallenge: const BluetoothPairingChallenge(
            id: 'c1',
            address: 'AA:BB',
            kind: BluetoothPairingChallengeKind.confirm,
          ),
        ),
        CyberConnectivityIconPhase.connecting,
      );
    });

    test('connected remote → connected', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.on,
          devices: const [
            BluetoothRemoteDevice(address: 'AA:BB', connected: true),
          ],
        ),
        CyberConnectivityIconPhase.connected,
      );
    });

    test('on + no connected remote → onIdle', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.on,
          devices: const [
            BluetoothRemoteDevice(address: 'AA:BB', paired: true),
          ],
        ),
        CyberConnectivityIconPhase.onIdle,
      );
    });
  });
}
