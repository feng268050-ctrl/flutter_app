import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';
import 'package:lws_hmi/platform/cloud/cloud_link_ui_status.dart';
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

/// Maps product cloud UI phase (origin probe + WS) into CyberUI cloud status.
CyberCloudLinkStatus mapCloudLinkStatus(CloudLinkUiPhase phase) {
  return switch (phase) {
    CloudLinkUiPhase.connecting => CyberCloudLinkStatus.connecting,
    CloudLinkUiPhase.connected => CyberCloudLinkStatus.connected,
    CloudLinkUiPhase.failed => CyberCloudLinkStatus.failed,
  };
}

/// This product's status-icon composition: cloud · Wi‑Fi · BT · camera · (lock).
///
/// Cloud appears only while Wi‑Fi is linked. Phase covers API origin probe and
/// device WebSocket (spinner while linking, cancel on failure, lit when up).
List<Widget> buildProductStatusIconItems({
  required CyberConnectivityIconPhase wifiPhase,
  required CyberConnectivityIconPhase bluetoothPhase,
  required CyberCameraLinkStatus cameraStatus,
  int? wifiSignalDbm,
  double iconSize = 28,
  bool remoteLocked = false,
  CyberCloudLinkStatus cloudStatus = CyberCloudLinkStatus.connecting,
}) {
  final wifiLinked = wifiPhase == CyberConnectivityIconPhase.connected;
  return [
    if (wifiLinked)
      CyberCloudStatusIcon(
        key: const ValueKey('home-status-cloud'),
        status: cloudStatus,
        size: iconSize,
      ),
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
    if (remoteLocked)
      Icon(
        Icons.lock,
        key: const ValueKey('home-status-remote-lock'),
        size: iconSize,
        color: CyberColors.textPrimary,
      ),
  ];
}
