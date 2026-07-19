import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  test('sim board profile loads', () {
    final json = File('$boardsRoot/sim.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.info.boardId, 'sim');
    expect(profile.capabilities.has(Capability.gpio), isFalse);
    expect(profile.capabilities.has(Capability.modbus), isFalse);
  });

  test('portable-smoke board profile loads', () {
    final json = File('$boardsRoot/portable-smoke.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.info.boardId, 'portable-smoke');
    expect(profile.ifaceFor(NetRole.ethernetPrimary), 'enp1s0');
    expect(profile.ifaceFor(NetRole.wifiStation), 'wlp2s0');
  });

  test('assets/ paths resolve without cyber_hal prefix', () {
    final profile = BoardProfile.fromJsonString('''
{
  "board_id": "example",
  "capabilities": ["gpio", "modbus"],
  "net_roles": {},
  "configs": {
    "gpio": "assets/hal/gpio.json",
    "modbus": "assets/hal/modbus.json"
  }
}
''');
    expect(profile.resolvedGpioAsset, 'assets/hal/gpio.json');
    expect(profile.resolvedModbusAsset, 'assets/hal/modbus.json');
  });
}
