import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  test('ynh960 board profile loads', () {
    final json = File('$boardsRoot/ynh960.json').readAsStringSync();
    final profile = BoardProfile.fromJsonString(json);
    expect(profile.info.boardId, 'ynh960');
    expect(profile.capabilities.has(Capability.gpio), isTrue);
    expect(profile.capabilities.has(Capability.modbus), isTrue);
    expect(profile.ifaceFor(NetRole.ethernetPrimary), 'eth0');
    expect(profile.ifaceFor(NetRole.wifiStation), 'wlan0');
    expect(profile.routeMetricFor('wlan0'), 100);
    expect(profile.routeMetricFor('eth0'), 2000);
  });

  test('ynh960 gpio.json loads via fromConfigFile', () {
    final hal = GpioHal.fromConfigFile('$boardsRoot/ynh960/gpio.json');
    expect(hal.config.lineById('led_red')!.fallbackLinuxGpio, 105);
    expect(hal.openLine('led_green').id, 'led_green');
  });

  test('ynh960 modbus.json loads via fromConfigFile', () {
    final hal = ModbusHal.fromConfigFile('$boardsRoot/ynh960/modbus.json');
    expect(hal.config.transport.device, '/dev/ttyS5');
    expect(hal.listAttributes(), isNotEmpty);
  });
}
