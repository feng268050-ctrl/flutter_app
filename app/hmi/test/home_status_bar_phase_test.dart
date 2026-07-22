import 'package:cyber_ui/cyber_ui.dart';
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
