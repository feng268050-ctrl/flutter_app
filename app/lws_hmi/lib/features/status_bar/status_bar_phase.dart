import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/wifi/wifi_models.dart';

/// Maps HAL Wi‑Fi radio + connection into a CyberUI status-bar phase.
CyberConnectivityIconPhase mapWifiStatusBarPhase({
  required WifiRadioState radio,
  required WifiConnectionPhase connection,
}) {
  if (radio == WifiRadioState.off) {
    return CyberConnectivityIconPhase.hidden;
  }
  if (radio == WifiRadioState.starting ||
      connection == WifiConnectionPhase.associating ||
      connection == WifiConnectionPhase.obtainingIp) {
    return CyberConnectivityIconPhase.connecting;
  }
  if (connection == WifiConnectionPhase.connected) {
    return CyberConnectivityIconPhase.connected;
  }
  return CyberConnectivityIconPhase.onIdle;
}

/// Maps HAL Bluetooth adapter + remotes into a CyberUI status-bar phase.
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

/// Maps product IP-camera UI phase into CyberUI camera link status.
CyberCameraLinkStatus mapCameraLinkStatus(IpCameraUiPhase phase) {
  return switch (phase) {
    IpCameraUiPhase.connecting => CyberCameraLinkStatus.connecting,
    IpCameraUiPhase.connected => CyberCameraLinkStatus.connected,
    IpCameraUiPhase.failed => CyberCameraLinkStatus.failed,
  };
}

/// This product's current status-icon composition: Wi‑Fi · BT · camera.
List<Widget> buildProductStatusIconItems({
  required CyberConnectivityIconPhase wifiPhase,
  required CyberConnectivityIconPhase bluetoothPhase,
  required CyberCameraLinkStatus cameraStatus,
  int? wifiSignalDbm,
  double iconSize = 28,
}) {
  return [
    if (wifiPhase != CyberConnectivityIconPhase.hidden)
      CyberWifiStatusIcon(
        key: const ValueKey('home-status-wifi'),
        phase: wifiPhase,
        signalDbm: wifiSignalDbm,
        size: iconSize,
      ),
    if (bluetoothPhase != CyberConnectivityIconPhase.hidden)
      CyberBluetoothStatusIcon(
        key: const ValueKey('home-status-bt'),
        phase: bluetoothPhase,
        size: iconSize,
      ),
    CyberCameraStatusIcon(
      key: const ValueKey('home-status-camera'),
      status: cameraStatus,
      size: iconSize,
    ),
  ];
}
