import 'package:cyber_hal/modbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/features/warn_alarm/application/alarm_monitor_state.dart';

void main() {
  group('MonitorModbusIds', () {
    test('alarmCatalog keeps only attributes with alarm_code', () {
      final attrs = [
        const ModbusAttributeConfig(
          id: 'alarm.gun_comm',
          access: 'r',
          register: ModbusRegisterBinding(space: 'input', address: 9),
          decode: ModbusDecode(type: 'bit', bit: 0),
          meta: ModbusAttributeMeta(alarmCode: 'H001', label: 'Gun comm'),
        ),
        const ModbusAttributeConfig(
          id: 'telemetry.gun_motor_temp',
          access: 'r',
          register: ModbusRegisterBinding(space: 'input', address: 0x61),
          decode: ModbusDecode(type: 'u16', scale: 0.1),
        ),
      ];
      final catalog = MonitorModbusIds.alarmCatalog(attrs);
      expect(catalog.keys, ['alarm.gun_comm']);
      expect(catalog['alarm.gun_comm']!.code, 'H001');
      expect(catalog['alarm.gun_comm']!.label, 'Gun comm');
    });

    test('watchIdsFromCatalog unions temps and alarms', () {
      final attrs = [
        const ModbusAttributeConfig(
          id: 'alarm.gun_comm',
          access: 'r',
          register: ModbusRegisterBinding(space: 'input', address: 9),
          decode: ModbusDecode(type: 'bit', bit: 0),
          meta: ModbusAttributeMeta(alarmCode: 'H001'),
        ),
      ];
      final ids = MonitorModbusIds.watchIdsFromCatalog(attrs);
      expect(ids, contains(MonitorModbusIds.motorTemp));
      expect(ids, contains('alarm.gun_comm'));
    });
  });

  group('AlarmMonitorState', () {
    test('unknown/null bits are fault; explicit false is ok', () {
      final s = AlarmMonitorState();
      expect(s.laserFault, isTrue);
      s.applyChanges(const [
        ModbusAttributeChange(id: 'alarm.laser_comm', value: false),
      ]);
      expect(s.laserFault, isFalse);
      s.applyChanges(const [
        ModbusAttributeChange(id: 'alarm.laser_comm', value: true),
      ]);
      expect(s.laserFault, isTrue);
    });

    test('applyChanges updates temps', () {
      final s = AlarmMonitorState();
      s.applyChanges(const [
        ModbusAttributeChange(id: 'telemetry.gun_motor_temp', value: 251),
      ]);
      expect(s.motor.display, contains('25.1'));
    });

    test('unhealthy Modbus forces fault display', () {
      final s = AlarmMonitorState();
      s.applyChanges(const [
        ModbusAttributeChange(id: 'alarm.gun_comm', value: false),
      ]);
      expect(s.gunFault, isFalse);
      s.applyHealth(
        const ModbusHealth(ok: false, message: 'window failed'),
      );
      expect(s.gunFault, isTrue);
    });
  });
}
