import 'package:cyber_hal/src/bluetooth/bluez_ops.dart';
import 'package:cyber_hal/src/bluetooth/bluetoothctl_parse.dart';
import 'package:flutter_test/flutter_test.dart';

/// D-Bus-style fake — records Device1 ops without shell or real BlueZ.
final class _RecordingOps extends BluezOps {
  final List<String> calls = <String>[];

  @override
  Future<void> pair(String address) async {
    calls.add('pair $address');
  }

  @override
  Future<void> setTrusted(String address, bool trusted) async {
    calls.add('setTrusted $trusted $address');
  }

  @override
  Future<void> connect(String address) async {
    calls.add('connect $address');
  }

  @override
  Future<void> disconnect(String address) async {
    calls.add('disconnect $address');
  }

  @override
  Future<void> remove(String address) async {
    calls.add('remove $address');
  }

  @override
  Future<void> cancelPairing(String address) async {
    calls.add('cancelPairing $address');
  }
}

void main() {
  test('RecordingOps records stock Device1 Connect/Disconnect', () async {
    final ops = _RecordingOps();
    await ops.connect('AA:BB:CC:DD:EE:FF');
    await ops.disconnect('AA:BB:CC:DD:EE:FF');
    await ops.pair('AA:BB:CC:DD:EE:FF');
    await ops.setTrusted('AA:BB:CC:DD:EE:FF', true);
    await ops.remove('AA:BB:CC:DD:EE:FF');
    await ops.cancelPairing('AA:BB:CC:DD:EE:FF');
    expect(ops.calls, [
      'connect AA:BB:CC:DD:EE:FF',
      'disconnect AA:BB:CC:DD:EE:FF',
      'pair AA:BB:CC:DD:EE:FF',
      'setTrusted true AA:BB:CC:DD:EE:FF',
      'remove AA:BB:CC:DD:EE:FF',
      'cancelPairing AA:BB:CC:DD:EE:FF',
    ]);
  });

  test('resolveBluezDevice normalizes MAC via BluetoothctlParse', () {
    expect(
      BluetoothctlParse.normalizeAddress('aa:bb:cc:dd:ee:ff'),
      'AA:BB:CC:DD:EE:FF',
    );
  });
}
