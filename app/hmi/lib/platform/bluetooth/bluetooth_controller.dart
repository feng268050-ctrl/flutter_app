import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';

/// HMI as discoverable peer (phones/PCs connect to us) — not a central scanner.
abstract class BluetoothController {
  Stream<BluetoothAdapterState> get adapterState;

  Stream<BluetoothAdapterInfo> get adapterInfo;

  /// Bonded / connected remotes that attached to this adapter.
  Stream<List<BluetoothRemoteDevice>> get incomingDevices;

  /// A2DP Sink (Bluetooth speaker) wanted/active — default off.
  Stream<bool> get a2dpSinkEnabled;

  /// Last known snapshots (streams are broadcast and do not replay).
  BluetoothAdapterState get currentAdapterState;

  BluetoothAdapterInfo get currentAdapterInfo;

  List<BluetoothRemoteDevice> get currentIncomingDevices;

  bool get currentA2dpSinkEnabled;

  Future<void> setAdapterEnabled(bool enabled);

  Future<void> setDiscoverable(bool enabled);

  Future<void> setPairable(bool enabled);

  /// Opt-in BlueZ-ALSA A2DP Sink (phone music → onboard speaker). Default off.
  Future<void> setA2dpSinkEnabled(bool enabled);

  Future<void> disconnectRemote(String address);

  Future<void> removeRemote(String address);

  /// Align adapter/A2DP UI with live stack (after boot restore).
  Future<void> syncFromSystem();

  /// Last stack bring-up error when [adapterState] is error; otherwise null.
  String? get lastError;

  Future<void> dispose();
}
