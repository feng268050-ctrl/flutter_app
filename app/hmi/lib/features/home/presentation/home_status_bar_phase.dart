import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Phone-like status-bar visibility/phase for Wi‑Fi / Bluetooth glyphs.
enum HomeConnectivityIconPhase {
  /// Radio/adapter off — do not render the glyph.
  hidden,

  /// In-progress (associating, adapter starting, pairing, …).
  connecting,

  /// Link up / at least one remote connected.
  connected,

  /// Enabled but not linked.
  onIdle,
}

/// Maps HAL Wi‑Fi radio + connection into a status-bar phase.
HomeConnectivityIconPhase mapWifiStatusBarPhase({
  required WifiRadioState radio,
  required WifiConnectionPhase connection,
}) {
  if (radio == WifiRadioState.off) {
    return HomeConnectivityIconPhase.hidden;
  }
  if (radio == WifiRadioState.starting ||
      connection == WifiConnectionPhase.associating ||
      connection == WifiConnectionPhase.obtainingIp) {
    return HomeConnectivityIconPhase.connecting;
  }
  if (connection == WifiConnectionPhase.connected) {
    return HomeConnectivityIconPhase.connected;
  }
  return HomeConnectivityIconPhase.onIdle;
}

/// Maps HAL Bluetooth adapter + remotes into a status-bar phase.
HomeConnectivityIconPhase mapBluetoothStatusBarPhase({
  required BluetoothAdapterState adapter,
  required Iterable<BluetoothRemoteDevice> devices,
  BluetoothPairingChallenge? pairingChallenge,
}) {
  if (adapter == BluetoothAdapterState.off) {
    return HomeConnectivityIconPhase.hidden;
  }
  if (adapter == BluetoothAdapterState.starting || pairingChallenge != null) {
    return HomeConnectivityIconPhase.connecting;
  }
  if (devices.any((d) => d.connected)) {
    return HomeConnectivityIconPhase.connected;
  }
  return HomeConnectivityIconPhase.onIdle;
}

/// Status-bar Wi‑Fi bar count from RSSI (dBm).
///
/// Returns **0** for “no link” callers, **1–4** when associated.
/// Unknown RSSI while connected → **4** (optimistic full bars).
int wifiSignalBarsFromDbm(int? signalDbm, {required bool linked}) {
  if (!linked) {
    return 0;
  }
  if (signalDbm == null) {
    return 4;
  }
  if (signalDbm >= -55) {
    return 4;
  }
  if (signalDbm >= -65) {
    return 3;
  }
  if (signalDbm >= -75) {
    return 2;
  }
  return 1;
}
