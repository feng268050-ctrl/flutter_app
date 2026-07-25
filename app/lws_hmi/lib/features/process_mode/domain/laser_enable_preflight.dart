import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

/// Pure laser-enable machine/alarm gates (lws-ui EngineerModeCheck + AlarmGuard).
abstract final class LaserEnablePreflight {
  /// Key switch / E-stop from status map values (`true`/`1` = active).
  static LaserEnableBlockReason? machineStatusBlock({
    required Object? emergencyStop,
    required Object? keySwitchOn,
  }) {
    if (emergencyStop == null || keySwitchOn == null) {
      return LaserEnableBlockReason.statusUnavailable;
    }
    if (_isOn(emergencyStop)) {
      return LaserEnableBlockReason.emergencyStop;
    }
    if (!_isOn(keySwitchOn)) {
      return LaserEnableBlockReason.keySwitchOff;
    }
    return null;
  }

  /// Coded-alarm gate using [LaserAlarmPolicy] + dangerous-ops snapshot.
  static LaserEnableBlockReason? alarmBlock({
    required Set<String> activeAlarmCodes,
    required LaserAlarmPolicySnapshot policy,
  }) {
    final gas = activeAlarmCodes.contains(LaserAlarmPolicy.alarmA001);
    final camera = activeAlarmCodes.contains(LaserAlarmPolicy.alarmC002);
    final lens = activeAlarmCodes.contains(LaserAlarmPolicy.alarmL001);
    final feeder = activeAlarmCodes.contains(LaserAlarmPolicy.alarmW001) ||
        activeAlarmCodes.contains(LaserAlarmPolicy.alarmW002);
    final other = activeAlarmCodes
        .any((code) => !LaserAlarmPolicy.isBypassableAlarmCode(code));

    final readyBlocked = LaserAlarmPolicy.isReadyIndicatorBlocked(
      gasBlocking: LaserAlarmPolicy.isGasBlocking(
        gasAlarmActive: gas,
        allowWorkAfterGasAlarm: policy.allowWorkAfterGasAlarm,
      ),
      cameraBlocking: LaserAlarmPolicy.isCameraBlocking(
        cameraAlarmActive: camera,
        allowWorkAfterCameraAlarm: policy.allowWorkAfterCameraAlarm,
      ),
      lensBlocking: LaserAlarmPolicy.isLensBlocking(
        lensAlarmActive: lens,
        allowWorkAfterLensContamination: policy.allowWorkAfterLensContamination,
      ),
      feederBlocking: LaserAlarmPolicy.isFeederBlocking(
        feederAlarmActive: feeder,
        allowWorkAfterFeederAlarm: policy.allowWorkAfterFeederAlarm,
      ),
      otherCodedWarnBlocking: other,
    );

    // Enable preflight: keepLaserOnWhileAlarmed only bypasses "other" coded
    // alarms (lws-ui LaserEnableAlarmGuard), not bypassable A001/C002/L001/W00x
    // when their allow-* is false. Ready indicator already applied allow-*.
    if (!readyBlocked) {
      return null;
    }
    if (other &&
        !gas &&
        !camera &&
        !lens &&
        !feeder &&
        policy.keepLaserOnWhileAlarmed) {
      return null;
    }
    return LaserEnableBlockReason.alarmBlocked;
  }

  static bool _isOn(Object? value) => value == true || value == 1;
}
