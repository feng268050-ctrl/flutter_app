import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden-style assertions: ynh960 gpio/modbus JSON vs former Demo maps.
void main() {
  final boardsRoot = Directory.current.path.endsWith('cyber_hal')
      ? 'boards'
      : 'packages/cyber_hal/boards';

  group('ynh960 gpio.json golden', () {
    late GpioConfig config;

    setUp(() {
      final json = File('$boardsRoot/ynh960/gpio.json').readAsStringSync();
      config = GpioConfig.fromJsonString(json);
    });

    test('matches former GpioLedConfig pin map', () {
      expect(config.version, 1);
      expect(config.backend, 'sysfs_innohi');
      expect(config.defaults.blinkOnMs, 1000);
      expect(config.defaults.blinkOffMs, 1000);
      expect(config.defaults.activeLow, isFalse);

      final expected = {
        'led_red': (label: 'GPIO_5', linux: 105),
        'led_yellow': (label: 'GPIO_4', linux: 106),
        'led_green': (label: 'GPIO_7', linux: 149),
      };
      for (final entry in expected.entries) {
        final line = config.lineById(entry.key)!;
        expect(line.label, entry.value.label);
        expect(line.fallbackLinuxGpio, entry.value.linux);
        expect(line.path, contains(entry.value.label));
      }
    });

    test('GpioHal openLine + unknown id', () {
      final hal = GpioHal.fromConfig(config);
      expect(hal.openLine('led_red').id, 'led_red');
      expect(hal.openLine('led_yellow').mode, GpioLineMode.off);
      expect(
        () => hal.openLine('led_blue'),
        throwsA(isA<HalNotFoundException>()),
      );
    });
  });

  group('ynh960 modbus.json golden', () {
    late ModbusConfig config;

    setUp(() {
      final json = File('$boardsRoot/ynh960/modbus.json').readAsStringSync();
      config = ModbusConfig.fromJsonString(json);
    });

    test('poll + groups + transport interval', () {
      expect(config.transport.commandIntervalMs, 50);
      expect(config.poll.intervalMs, 100);
      expect(config.poll.discardIfBusy, isTrue);
      expect(config.poll.health?.windowSize, 5);
      expect(config.poll.health?.failureThreshold, 3);
      expect(config.poll.health?.mode, 'slide_window');
      expect(config.capabilities.writeMultiple, isTrue);

      expect(config.groups.keys, containsAll(['status', 'data', 'info']));
      final status = config.groupById('status')!;
      expect(status.start, 0x0000);
      expect(status.count, 23);
      expect(status.mode, 'continuous');
      expect(status.chain, 'data');

      final data = config.groupById('data')!;
      expect(data.start, 0x0060);
      expect(data.count, 19);
      expect(data.mode, 'continuous');
      expect(data.chain, isNull);

      final info = config.groupById('info')!;
      expect(info.start, 0x0030);
      expect(info.count, 10);
      expect(info.mode, 'on_demand');
    });

    test('matches former *RegisterAddress map + bit alarms', () {
      expect(config.transport.device, '/dev/ttyS5');
      expect(config.transport.baud, 115200);
      expect(config.transport.unitId, 1);
      expect(config.transport.timeoutMs, 500);

      final expected = <String, (String space, int address, int count, String type, String? group)>{
        'device.control_card_version': ('input', 0x0002, 1, 'u16', 'status'),
        'alarm.gun_comm': ('input', 0x0009, 1, 'bit', 'status'),
        'alarm.gun_motor_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.driver_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.protective_mirror_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.collimator_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.laser_comm': ('input', 0x000D, 1, 'bit', 'status'),
        'alarm.wire_feeder_comm': ('input', 0x0011, 1, 'bit', 'status'),
        'alarm.shielding_gas': ('input', 0x0013, 1, 'bit', 'status'),
        'device.laser_hw_version': ('input', 0x0030, 2, 'u16_pair_be', 'info'),
        'device.laser_sw_version': ('input', 0x0032, 2, 'u16_pair_be', 'info'),
        'device.wire_feeder_hw_version': ('input', 0x0034, 1, 'u16', 'info'),
        'device.wire_feeder_sw_version': ('input', 0x0035, 1, 'u16', 'info'),
        'device.gun_head_hw_version': ('input', 0x0036, 1, 'u16', 'info'),
        'device.gun_head_sw_version': ('input', 0x0037, 1, 'u16', 'info'),
        'device.gun_head_sn': ('input', 0x0038, 2, 'u16_pair_be', 'info'),
        'alarm.gun_motor_temp': ('input', 0x0061, 1, 's16', 'data'),
        'alarm.gun_motor_drive_temp': ('input', 0x0062, 1, 's16', 'data'),
        'alarm.protective_cover_temp': ('input', 0x0063, 1, 's16', 'data'),
        'alarm.collimator_temp': ('input', 0x0064, 1, 's16', 'data'),
      };

      expect(config.attributes.length, expected.length);
      for (final entry in expected.entries) {
        final attr = config.attributeById(entry.key)!;
        expect(attr.register.space, entry.value.$1, reason: entry.key);
        expect(attr.register.address, entry.value.$2, reason: entry.key);
        expect(attr.register.count, entry.value.$3, reason: entry.key);
        expect(attr.decode.type, entry.value.$4, reason: entry.key);
        expect(attr.group, entry.value.$5, reason: entry.key);
      }

      final gunComm = config.attributeById('alarm.gun_comm')!;
      expect(gunComm.decode.bit, 0);
      expect(gunComm.decode.activeHigh, isTrue);
      expect(gunComm.meta?.alarmCode, 'H001');

      final gas = config.attributeById('alarm.shielding_gas')!;
      expect(gas.decode.bit, 0);
      expect(gas.meta?.alarmCode, 'A001');

      final laser = config.attributeById('alarm.laser_comm')!;
      expect(laser.decode.bit, 0);
      expect(laser.register.address, 0x000D);

      final motorOt = config.attributeById('alarm.gun_motor_over_temp')!;
      expect(motorOt.decode.bit, 0);
      expect(motorOt.register.address, 0x000B);

      final motor = config.attributeById('alarm.gun_motor_temp')!;
      expect(motor.decode.scale, 0.1);
    });

    test('ModbusHal listAttributes + unknown id', () async {
      final hal = ModbusHal.fromConfig(config);
      expect(hal.listAttributes(), hasLength(config.attributes.length));
      await expectLater(
        hal.readAttribute('missing.attr'),
        throwsA(isA<HalNotFoundException>()),
      );
    });
  });

  group('modbus config backward compatible', () {
    test('missing poll/groups use defaults', () {
      const minimal = '''
{
  "version": 1,
  "transport": {
    "type": "rtu",
    "device": "/dev/ttyUSB0",
    "baud": 9600
  },
  "attributes": [
    {
      "id": "x.value",
      "access": "r",
      "register": { "space": "input", "address": "0x0001", "count": 1 },
      "decode": { "type": "u16" }
    }
  ]
}
''';
      final config = ModbusConfig.fromJsonString(minimal);
      expect(config.poll.intervalMs, 100);
      expect(config.poll.discardIfBusy, isTrue);
      expect(config.poll.health, isNull);
      expect(config.groups, isEmpty);
      expect(config.transport.commandIntervalMs, 50);
      expect(config.capabilities.writeMultiple, isNull);
    });
  });
}
