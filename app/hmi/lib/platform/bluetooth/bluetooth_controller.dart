import 'package:lws_hmi/platform/bluetooth/bluetooth_models.dart';

/// Local adapter + central discovery/pairing for supported peripherals.
abstract class BluetoothController {
  Stream<BluetoothAdapterState> get adapterState;

  Stream<BluetoothAdapterInfo> get adapterInfo;

  /// Unified bonded / connected / discovered remotes (keyed by address).
  Stream<List<BluetoothRemoteDevice>> get devices;

  /// Alias for [devices] (historical "incoming" naming).
  Stream<List<BluetoothRemoteDevice>> get incomingDevices => devices;

  Stream<bool> get scanning;

  Stream<BluetoothPairingChallenge?> get pairingChallenge;

  /// A2DP Sink (Bluetooth speaker) wanted/active — default off.
  Stream<bool> get a2dpSinkEnabled;

  BluetoothAdapterState get currentAdapterState;

  BluetoothAdapterInfo get currentAdapterInfo;

  List<BluetoothRemoteDevice> get currentDevices;

  List<BluetoothRemoteDevice> get currentIncomingDevices => currentDevices;

  bool get currentScanning;

  BluetoothPairingChallenge? get currentPairingChallenge;

  bool get currentA2dpSinkEnabled;

  Future<void> setAdapterEnabled(bool enabled);

  Future<void> setDiscoverable(bool enabled);

  Future<void> setPairable(bool enabled);

  /// Opt-in BlueZ-ALSA A2DP Sink (phone music → onboard speaker). Default off.
  Future<void> setA2dpSinkEnabled(bool enabled);

  /// Bounded discovery (default 15s). Idempotent if already scanning.
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)});

  Future<void> stopScan();

  /// Pair (if needed), trust, and connect. Stops discovery first.
  Future<void> pairAndConnect(String address);

  Future<void> disconnectRemote(String address);

  Future<void> removeRemote(String address);

  /// Accept / reject an outstanding pairing challenge from [pairingChallenge].
  Future<void> respondToPairingChallenge(
    String challengeId, {
    required bool accept,
    int? passkey,
    String? pinCode,
  });

  /// Align adapter/A2DP UI with live stack (after boot restore).
  Future<void> syncFromSystem();

  /// Last stack bring-up error when [adapterState] is error; otherwise null.
  String? get lastError;

  Future<void> dispose();
}
