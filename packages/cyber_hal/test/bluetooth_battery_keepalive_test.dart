import 'package:cyber_hal/bluetooth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KeyboardBatteryKeepalive ticks and can be stopped', () async {
    var ticks = 0;
    final keepalive = KeyboardBatteryKeepalive(
      interval: const Duration(milliseconds: 30),
      readPercent: (_) async => 42,
    );
    keepalive.start(() async {
      ticks++;
    });
    expect(keepalive.isActive, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    keepalive.stop();
    expect(keepalive.isActive, isFalse);
    expect(ticks, greaterThanOrEqualTo(2));
    expect(await keepalive.readPercent('/org/bluez/hci0/dev_AA'), 42);
  });

  test('BluetoothRemoteDevice batteryPercent copyWith', () {
    const d = BluetoothRemoteDevice(address: 'AA:BB', batteryPercent: 80);
    expect(d.copyWith(batteryPercent: 50).batteryPercent, 50);
    expect(d.copyWith(clearBatteryPercent: true).batteryPercent, isNull);
  });
}
