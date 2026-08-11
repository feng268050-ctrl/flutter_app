import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden-style assertions: ynh960 gpio/modbus JSON vs former Demo maps.
void main() {
  final halRoot = Directory.current.path.endsWith('lws_hmi')
      ? 'assets/hal'
      : 'app/lws_hmi/assets/hal';

  group('app gpio.json golden', () {
    late GpioConfig config;

    setUp(() {
      final json = File('$halRoot/gpio.json').readAsStringSync();
      config = GpioConfig.fromJsonString(json);
    });

    test('matches former GpioLedConfig pin map', () {
      expect(config.version, 2);
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

      final bank = config.deviceById('chassis_rgb')!.statusLed!;
      expect(bank.channelById('red')!.binding.offset, 9);
      expect(config.deviceById('panel_buzzer')!.buzzer!.line.label, 'BELL');
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

  group('app modbus.json golden', () {
    late ModbusConfig config;

    setUp(() {
      final json = File('$halRoot/modbus.json').readAsStringSync();
      config = ModbusConfig.fromJsonString(json);
    });

    test('poll + groups + transport interval', () {
      expect(config.transport.commandIntervalMs, 50);
      expect(config.poll.intervalMs, 100);
      expect(config.poll.discardIfBusy, isTrue);
      expect(config.poll.health?.windowSize, 5);
      expect(config.poll.health?.failureThreshold, 3);
      expect(config.poll.health?.mode, 'slide_window');
      expect(config.capabilities.readHolding, isTrue);
      expect(config.capabilities.readInput, isTrue);
      expect(config.capabilities.writeSingle, isFalse);
      expect(config.capabilities.writeMultiple, isTrue);

      expect(
        config.groups.keys,
        containsAll([
          'status',
          'data',
          'info',
          'control',
          'process',
          'settings',
          'upgrade',
        ]),
      );
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

      final control = config.groupById('control')!;
      expect(control.space, 'holding');
      expect(control.start, 0x0050);
      expect(control.count, 9);
      expect(control.mode, 'on_demand');

      final process = config.groupById('process')!;
      expect(process.space, 'holding');
      expect(process.start, 0x0060);
      // Match lws-ui createProcessParametersData: 0x0060..0x0075.
      expect(process.count, 22);

      final settings = config.groupById('settings')!;
      expect(settings.start, 0x0090);
      expect(settings.count, 16);

      final upgrade = config.groupById('upgrade')!;
      expect(upgrade.start, 0x0000);
      expect(upgrade.count, 80);
    });

    test('full lws-ui catalog size + sampled bindings', () {
      expect(config.transport.device, '/dev/ttyS5');
      expect(config.transport.baud, 115200);
      expect(config.transport.unitId, 1);
      expect(config.transport.timeoutMs, 500);

      // Full product catalog (alarms + machine + telemetry + holdings).
      expect(config.attributes.length, 155);

      final samples = <String,
          (String space, int address, int count, String type, String? group)>{
        'device.control_card_version': ('input', 0x0002, 1, 'u16', 'status'),
        'alarm.gun_comm': ('input', 0x0009, 1, 'bit', 'status'),
        'alarm.gun_motor_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.driver_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.protective_mirror_over_temp': (
          'input',
          0x000B,
          1,
          'bit',
          'status'
        ),
        'alarm.collimator_over_temp': ('input', 0x000B, 1, 'bit', 'status'),
        'alarm.laser_comm': ('input', 0x000D, 1, 'bit', 'status'),
        'alarm.env_temperature': ('input', 0x000F, 1, 'bit', 'status'),
        'alarm.wire_feeder_comm': ('input', 0x0011, 1, 'bit', 'status'),
        'alarm.shielding_gas_blow_pressure': (
          'input',
          0x0013,
          1,
          'bit',
          'status'
        ),
        'machine.laser_on': ('input', 0x0015, 1, 'bit', 'status'),
        'machine.cnc_connected': ('input', 0x0015, 1, 'bit', 'status'),
        'device.laser_hw_version': ('input', 0x0030, 2, 'u16_pair_be', 'info'),
        'device.laser_sw_version': ('input', 0x0032, 2, 'u16_pair_be', 'info'),
        'device.wire_feeder_hw_version': ('input', 0x0034, 1, 'u16', 'info'),
        'device.wire_feeder_sw_version': ('input', 0x0035, 1, 'u16', 'info'),
        'device.gun_head_hw_version': ('input', 0x0036, 1, 'u16', 'info'),
        'device.gun_head_sw_version': ('input', 0x0037, 1, 'u16', 'info'),
        'device.gun_head_sn': ('input', 0x0038, 2, 'u16_pair_be', 'info'),
        'telemetry.gun_motor_temp': ('input', 0x0061, 1, 's16', 'data'),
        'telemetry.gun_motor_drive_temp': ('input', 0x0062, 1, 's16', 'data'),
        'telemetry.protective_cover_temp': ('input', 0x0063, 1, 's16', 'data'),
        'telemetry.collimator_temp': ('input', 0x0064, 1, 's16', 'data'),
        'telemetry.blow_pressure': ('input', 0x0060, 1, 'u16', 'data'),
        'control.laser_enable': ('holding', 0x0058, 1, 'bit', 'control'),
        'control.manual_gas': ('holding', 0x0058, 1, 'bit', 'control'),
        'machine.wire_feeding_on': ('input', 0x0015, 1, 'bit', 'status'),
        'process.laser_power': ('holding', 0x0060, 1, 'u16', 'process'),
        'process.swing_width': ('holding', 0x0067, 1, 'u16', 'process'),
        'setting.motor_temp_alarm_threshold': (
          'holding',
          0x009E,
          1,
          'u16',
          'settings'
        ),
        'upgrade.fw_command': ('holding', 0x0009, 1, 'u16', 'upgrade'),
        'upgrade.data': ('holding', 0x0010, 64, 'u16_array', 'upgrade'),
      };

      for (final entry in samples.entries) {
        final attr = config.attributeById(entry.key);
        expect(attr, isNotNull, reason: entry.key);
        expect(attr!.register.space, entry.value.$1, reason: entry.key);
        expect(attr.register.address, entry.value.$2, reason: entry.key);
        expect(attr.register.count, entry.value.$3, reason: entry.key);
        expect(attr.decode.type, entry.value.$4, reason: entry.key);
        expect(attr.group, entry.value.$5, reason: entry.key);
      }

      final gunComm = config.attributeById('alarm.gun_comm')!;
      expect(gunComm.decode.bit, 0);
      expect(gunComm.decode.activeHigh, isTrue);
      expect(gunComm.meta?.alarmCode, 'H001');

      final gas = config.attributeById('alarm.shielding_gas_blow_pressure')!;
      expect(gas.decode.bit, 0);
      expect(gas.meta?.alarmCode, 'A001');

      final env = config.attributeById('alarm.env_temperature')!;
      expect(env.decode.bit, 3);
      expect(env.meta?.alarmCode, 'H033');

      final motor = config.attributeById('telemetry.gun_motor_temp')!;
      expect(motor.decode.scale, 0.1);
      expect(motor.access, 'r');

      final swing = config.attributeById('process.swing_width')!;
      expect(swing.decode.scale, 0.1);
      expect(swing.access, 'rw');

      final laserEnable = config.attributeById('control.laser_enable')!;
      expect(laserEnable.decode.bit, 0);
      expect(laserEnable.access, 'rw');

      final manualGas = config.attributeById('control.manual_gas')!;
      expect(manualGas.decode.bit, 1);
      expect(manualGas.access, 'rw');

      final wireFeeding = config.attributeById('machine.wire_feeding_on')!;
      expect(wireFeeding.decode.bit, 2);
      expect(wireFeeding.access, 'r');
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
