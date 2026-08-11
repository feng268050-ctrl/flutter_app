import 'package:cyber_hal/bluetooth.dart';
import 'package:cyber_hal/network.dart';
import 'package:cyber_ui/cyber_ui.dart';

CyberConnectivityIconPhase mapWifiStatusBarPhase({
  required WifiRadioState radio,
  required WifiConnectionState conn,
}) {
  if (radio == WifiRadioState.off) {
    return CyberConnectivityIconPhase.hidden;
  }
  if (radio == WifiRadioState.starting ||
      conn.phase == WifiConnectionPhase.associating ||
      conn.phase == WifiConnectionPhase.obtainingIp) {
    return CyberConnectivityIconPhase.connecting;
  }
  if (conn.isAssociated) {
    return CyberConnectivityIconPhase.connected;
  }
  return CyberConnectivityIconPhase.onIdle;
}

CyberConnectivityIconPhase mapBluetoothStatusBarPhase({
  required BluetoothAdapterState adapter,
  required Iterable<BluetoothRemoteDevice> devices,
  BluetoothPairingChallenge? pairingChallenge,
}) {
  if (adapter == BluetoothAdapterState.off) {
    return CyberConnectivityIconPhase.hidden;
  }
  if (adapter == BluetoothAdapterState.starting || pairingChallenge != null) {
    return CyberConnectivityIconPhase.connecting;
  }
  if (devices.any((d) => d.connected)) {
    return CyberConnectivityIconPhase.connected;
  }
  return CyberConnectivityIconPhase.onIdle;
}
