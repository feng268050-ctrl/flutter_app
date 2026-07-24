import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/domain/laser_enable_preflight.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

void main() {
  group('LaserEnablePreflight.machineStatusBlock', () {
    test('blocks on e-stop', () {
      expect(
        LaserEnablePreflight.machineStatusBlock(
          emergencyStop: true,
          keySwitchOn: true,
        ),
        LaserEnableBlockReason.emergencyStop,
      );
    });

    test('blocks on key switch off', () {
      expect(
        LaserEnablePreflight.machineStatusBlock(
          emergencyStop: false,
          keySwitchOn: false,
        ),
        LaserEnableBlockReason.keySwitchOff,
      );
    });

    test('passes when clear', () {
      expect(
        LaserEnablePreflight.machineStatusBlock(
          emergencyStop: false,
          keySwitchOn: true,
        ),
        isNull,
      );
    });
  });

  group('LaserEnablePreflight.alarmBlock', () {
    const strict = LaserAlarmPolicySnapshot(
      keepLaserOnWhileAlarmed: false,
      allowWorkAfterCameraAlarm: false,
      allowWorkAfterGasAlarm: false,
      allowWorkAfterLensContamination: false,
      allowWorkAfterFeederAlarm: false,
    );

    test('blocks on A001 without bypass', () {
      expect(
        LaserEnablePreflight.alarmBlock(
          activeAlarmCodes: {LaserAlarmPolicy.alarmA001},
          policy: strict,
        ),
        LaserEnableBlockReason.alarmBlocked,
      );
    });

    test('allows A001 when gas bypass enabled', () {
      expect(
        LaserEnablePreflight.alarmBlock(
          activeAlarmCodes: {LaserAlarmPolicy.alarmA001},
          policy: const LaserAlarmPolicySnapshot(
            keepLaserOnWhileAlarmed: false,
            allowWorkAfterCameraAlarm: false,
            allowWorkAfterGasAlarm: true,
            allowWorkAfterLensContamination: false,
            allowWorkAfterFeederAlarm: false,
          ),
        ),
        isNull,
      );
    });

    test('keepLaserOnWhileAlarmed bypasses other coded alarms only', () {
      expect(
        LaserEnablePreflight.alarmBlock(
          activeAlarmCodes: {'X999'},
          policy: const LaserAlarmPolicySnapshot(
            keepLaserOnWhileAlarmed: true,
            allowWorkAfterCameraAlarm: false,
            allowWorkAfterGasAlarm: false,
            allowWorkAfterLensContamination: false,
            allowWorkAfterFeederAlarm: false,
          ),
        ),
        isNull,
      );
    });
  });
}
