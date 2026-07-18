import 'package:bluez/bluez.dart';
import 'package:cyber_hal/src/bluetooth/bluetoothctl_parse.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Resolve [address] among [client].devices (normalized MAC).
BlueZDevice? resolveBluezDevice(BlueZClient client, String address) {
  final want = BluetoothctlParse.normalizeAddress(address);
  for (final d in client.devices) {
    if (BluetoothctlParse.normalizeAddress(d.address) == want) {
      return d;
    }
  }
  return null;
}

/// Device1 write path over BlueZ D-Bus (no `bluetoothctl` / `busctl` shell).
///
/// Product default is [DBusBluezOps] against **upstream** BlueZ
/// (`Connect`/`Disconnect` empty signatures). Tests may substitute a fake.
abstract class BluezOps {
  /// Pair Device1 for [address] (MAC).
  Future<void> pair(String address);

  Future<void> setTrusted(String address, bool trusted);

  /// Stock BlueZ [BlueZDevice.connect] (empty D-Bus signature).
  Future<void> connect(String address);

  /// Stock BlueZ [BlueZDevice.disconnect] (empty D-Bus signature).
  Future<void> disconnect(String address);

  /// [BlueZAdapter.removeDevice] for [address].
  Future<void> remove(String address);

  Future<void> cancelPairing(String address);
}

/// BlueZ D-Bus implementation via the `bluez` package (upstream Device1 API).
final class DBusBluezOps extends BluezOps {
  DBusBluezOps(this.clientOf);

  /// Live [BlueZClient] (adapter/device objects resolved each call).
  final BlueZClient Function() clientOf;

  BlueZDevice _requireDevice(String address) {
    final d = resolveBluezDevice(clientOf(), address);
    if (d == null) {
      throw StateError('No BlueZ Device1 for $address');
    }
    return d;
  }

  BlueZAdapter _requireAdapter() {
    final adapters = clientOf().adapters;
    if (adapters.isEmpty) {
      throw StateError('No BlueZ adapter');
    }
    return adapters.first;
  }

  @override
  Future<void> pair(String address) async {
    final d = _requireDevice(address);
    lwsTrace('bt: Device1.Pair $address');
    await d.pair();
  }

  @override
  Future<void> setTrusted(String address, bool trusted) async {
    final d = _requireDevice(address);
    lwsTrace('bt: Device1.Trusted=$trusted $address');
    await d.setTrusted(trusted);
  }

  @override
  Future<void> connect(String address) async {
    final d = _requireDevice(address);
    lwsTrace('bt: Device1.Connect $address');
    await d.connect();
  }

  @override
  Future<void> disconnect(String address) async {
    final d = _requireDevice(address);
    lwsTrace('bt: Device1.Disconnect $address');
    await d.disconnect();
  }

  @override
  Future<void> remove(String address) async {
    final d = _requireDevice(address);
    final a = _requireAdapter();
    lwsTrace('bt: Adapter1.RemoveDevice $address');
    await a.removeDevice(d);
  }

  @override
  Future<void> cancelPairing(String address) async {
    final d = resolveBluezDevice(clientOf(), address);
    if (d == null) {
      return;
    }
    lwsTrace('bt: Device1.CancelPairing $address');
    await d.cancelPairing();
  }
}
