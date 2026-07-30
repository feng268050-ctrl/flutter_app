import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot_modbus_mapper.dart';

void main() {
  group('DeviceRemoteSnapshotModbusMapper', () {
    test('rebuilds DeviceStatus segments from bit attributes', () {
      final status = DeviceRemoteSnapshotModbusMapper.deviceStatusFromGroup(
        {
          'device.type': 1,
          'device.control_hw_version': 0x0102,
          'alarm.gun_comm': true,
          'alarm.laser_comm': true,
          'machine.laser_on': true,
          'machine.emergency_stop': false,
          'machine.key_switch_on': true,
        },
        cameraStatus: 1,
      );
      expect(status['cameraStatus'], 1);
      expect(status['deviceType'], 1);
      expect(status['hardwareVersion'], 0x0102);
      expect(status['gunAlarmSeg1'], 1);
      expect(status['laserAlarmSeg1'], 1);
      expect(status['machineStatusSeg1'], 1 | (1 << 6));
    });

    test('clears laser/wire feeder comm bits when e-stop active', () {
      final status = DeviceRemoteSnapshotModbusMapper.deviceStatusFromGroup(
        {
          'alarm.laser_comm': true,
          'alarm.wire_feeder_comm': true,
          'machine.emergency_stop': true,
        },
        cameraStatus: 0,
      );
      expect(status['laserAlarmSeg1'], 0);
      expect(status['wireFeederAlarmSeg1'], 0);
      expect(status['machineStatusSeg1'], 1 << 7);
    });

    test('maps DeviceData telemetry keys', () {
      final data = DeviceRemoteSnapshotModbusMapper.deviceDataFromGroup({
        'telemetry.blow_pressure': 120,
        'telemetry.gun_motor_temp': -9990,
        'telemetry.laser_current': 42,
      });
      expect(data['blowAirPressure'], 120);
      expect(data['gunMotorTempRaw'], -9990);
      expect(data['laserCurrent'], 42);
    });

    test('re-encodes HAL-scaled temps to lws-ui TempRaw ×10', () {
      final data = DeviceRemoteSnapshotModbusMapper.deviceDataFromGroup({
        'telemetry.gun_motor_temp': 41.9,
        'telemetry.gun_motor_drive_temp': 25.0,
        'telemetry.protective_cover_temp': -999.0,
        'telemetry.collimator_temp': 0.0,
      });
      // 41.9 °C → 419 raw → mobile /10 → 41.9 °C → 107.4 °F
      expect(data['gunMotorTempRaw'], 419);
      expect(data['gunDriverBoardTempRaw'], 250);
      expect(data['protectionBoardTempRaw'], -9990);
      expect(data['collimatorTempRaw'], 0);
    });

    test('omits DeviceData keys for attrs absent from the HAL map', () {
      final data = DeviceRemoteSnapshotModbusMapper.deviceDataFromGroup({
        'telemetry.gun_motor_temp': 41.9,
        'telemetry.laser_current': 42,
      });
      expect(data['gunMotorTempRaw'], 419);
      expect(data['laserCurrent'], 42);
      expect(data.containsKey('gunDriverBoardTempRaw'), isFalse);
      expect(data.containsKey('protectionBoardTempRaw'), isFalse);
      expect(data.containsKey('collimatorTempRaw'), isFalse);
    });

    test('maps WarnTable fields from AlarmLogEntry', () {
      final row = DeviceRemoteSnapshotModbusMapper.warnTableFromAlarmLog(
        AlarmLogEntry(
          id: 7,
          code: 'H001',
          title: 'Gun head communication',
          timestamp: DateTime.utc(2026, 7, 30, 2, 15, 30),
          level: 1,
        ),
      );
      expect(row['id'], 7);
      expect(row['code'], 'H001');
      expect(row['content'], 'Gun head communication');
      expect(row['level'], 1);
      expect(row['time'], DateTime.utc(2026, 7, 30, 2, 15, 30).millisecondsSinceEpoch);
      expect(row['ymdDate'], isNotEmpty);
      expect(row['hmDate'], isNotEmpty);
    });

    test('maps DeviceInfo from Modbus info + status', () {
      final info = DeviceRemoteSnapshotModbusMapper.deviceInfoFromSources(
        deviceSn: 'abc123',
        brand: 'LaserCyber',
        model: 'L1',
        systemVersion: '1.2.3',
        cameraIp: '192.168.1.50',
        cameraVersion: 'cam-9',
        hostIp: '10.0.0.2',
        focusScaleRef: 42,
        infoGroup: {
          'device.gun_head_sn': 'a1b2',
          'device.laser_sw_version': 'c3d4',
          'device.laser_hw_version': 'e5f6',
          'device.wire_feeder_sw_version': 11,
          'device.wire_feeder_hw_version': 22,
          'device.gun_head_hw_version': 33,
          'device.gun_head_sw_version': 44,
        },
        statusGroup: {
          'device.control_card_version': 1007,
        },
        processLibVersion: '2.0.1',
      );
      expect(info['deviceSn'], 'abc123');
      expect(info['sn'], 'abc123');
      expect(info['firmwareVersion'], '1007');
      expect(info['gunSn'], 'a1b2');
      expect(info['laserVersion'], 'c3d4');
      expect(info['laserHardwareVersion'], 'e5f6');
      expect(info['wireFeederVersion'], '11');
      expect(info['wireFeederHardwareVersion'], '22');
      expect(info['gunHeadHardwareVersion'], '33');
      expect(info['gunHeadSoftwareVersion'], '44');
      expect(info['processLibVersion'], '2.0.1');
      expect(info['cameraIp'], '192.168.1.50');
      expect(info['focusScaleRef'], 42);
      expect(info['aiVersion'], '');
      expect(info['mainControlSn'], '');
    });

    test('DeviceInfo uses firmware/processLib placeholders when empty', () {
      final info = DeviceRemoteSnapshotModbusMapper.deviceInfoFromSources(
        deviceSn: 'x',
        model: 'm',
      );
      expect(info['firmwareVersion'], '1000');
      expect(info['processLibVersion'], '--');
      expect(info['gunSn'], '');
    });
  });
}
