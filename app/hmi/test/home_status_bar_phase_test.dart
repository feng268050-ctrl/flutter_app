import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/home_status_bar_phase.dart';
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
        HomeConnectivityIconPhase.hidden,
      );
    });

    test('starting → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.starting,
          connection: WifiConnectionPhase.disconnected,
        ),
        HomeConnectivityIconPhase.connecting,
      );
    });

    test('associating → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.associating,
        ),
        HomeConnectivityIconPhase.connecting,
      );
    });

    test('obtainingIp → connecting', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.obtainingIp,
        ),
        HomeConnectivityIconPhase.connecting,
      );
    });

    test('connected → connected', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.connected,
        ),
        HomeConnectivityIconPhase.connected,
      );
    });

    test('on + disconnected → onIdle', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.on,
          connection: WifiConnectionPhase.disconnected,
        ),
        HomeConnectivityIconPhase.onIdle,
      );
    });

    test('error + failed → onIdle (still visible)', () {
      expect(
        mapWifiStatusBarPhase(
          radio: WifiRadioState.error,
          connection: WifiConnectionPhase.failed,
        ),
        HomeConnectivityIconPhase.onIdle,
      );
    });
  });

  group('mapBluetoothStatusBarPhase', () {
    test('off → hidden', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.off,
          devices: const [],
        ),
        HomeConnectivityIconPhase.hidden,
      );
    });

    test('starting → connecting', () {
      expect(
        mapBluetoothStatusBarPhase(
          adapter: BluetoothAdapterState.starting,
          devices: const [],
        ),
        HomeConnectivityIconPhase.connecting,
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
        HomeConnectivityIconPhase.connecting,
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
        HomeConnectivityIconPhase.connected,
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
        HomeConnectivityIconPhase.onIdle,
      );
    });
  });

  group('wifiSignalBarsFromDbm', () {
    test('unlinked → 0', () {
      expect(wifiSignalBarsFromDbm(-40, linked: false), 0);
    });

    test('linked + null → 4', () {
      expect(wifiSignalBarsFromDbm(null, linked: true), 4);
    });

    test('thresholds map to 1–4 bars', () {
      expect(wifiSignalBarsFromDbm(-40, linked: true), 4);
      expect(wifiSignalBarsFromDbm(-60, linked: true), 3);
      expect(wifiSignalBarsFromDbm(-70, linked: true), 2);
      expect(wifiSignalBarsFromDbm(-85, linked: true), 1);
    });
  });
}
