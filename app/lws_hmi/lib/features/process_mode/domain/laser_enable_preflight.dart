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
    if (firstBlockingAlarmCode(
          activeAlarmCodes: activeAlarmCodes,
          policy: policy,
        ) ==
        null) {
      return null;
    }
    return LaserEnableBlockReason.alarmBlocked;
  }

  /// First coded alarm that blocks Laser Enable (lws-ui LaserEnableAlarmGuard
  /// order: A001 → C002 → L001 → feeder → other).
  static String? firstBlockingAlarmCode({
    required Set<String> activeAlarmCodes,
    required LaserAlarmPolicySnapshot policy,
  }) {
    final gas = activeAlarmCodes.contains(LaserAlarmPolicy.alarmA001);
    final camera = activeAlarmCodes.contains(LaserAlarmPolicy.alarmC002);
    final lens = activeAlarmCodes.contains(LaserAlarmPolicy.alarmL001);
    final feeder = activeAlarmCodes.contains(LaserAlarmPolicy.alarmW001) ||
        activeAlarmCodes.contains(LaserAlarmPolicy.alarmW002);
    final otherCodes = activeAlarmCodes
        .where((code) => !LaserAlarmPolicy.isBypassableAlarmCode(code))
        .toList()
      ..sort();

    if (LaserAlarmPolicy.isGasBlocking(
      gasAlarmActive: gas,
      allowWorkAfterGasAlarm: policy.allowWorkAfterGasAlarm,
    )) {
      return LaserAlarmPolicy.alarmA001;
    }
    if (LaserAlarmPolicy.isCameraBlocking(
      cameraAlarmActive: camera,
      allowWorkAfterCameraAlarm: policy.allowWorkAfterCameraAlarm,
    )) {
      return LaserAlarmPolicy.alarmC002;
    }
    if (LaserAlarmPolicy.isLensBlocking(
      lensAlarmActive: lens,
      allowWorkAfterLensContamination: policy.allowWorkAfterLensContamination,
    )) {
      return LaserAlarmPolicy.alarmL001;
    }
    if (LaserAlarmPolicy.isFeederBlocking(
      feederAlarmActive: feeder,
      allowWorkAfterFeederAlarm: policy.allowWorkAfterFeederAlarm,
    )) {
      return activeAlarmCodes.contains(LaserAlarmPolicy.alarmW001)
          ? LaserAlarmPolicy.alarmW001
          : LaserAlarmPolicy.alarmW002;
    }

    final other = otherCodes.isNotEmpty;
    final readyBlocked = LaserAlarmPolicy.isReadyIndicatorBlocked(
      gasBlocking: false,
      cameraBlocking: false,
      lensBlocking: false,
      feederBlocking: false,
      otherCodedWarnBlocking: other,
    );
    if (!readyBlocked) {
      return null;
    }
    if (other && policy.keepLaserOnWhileAlarmed) {
      return null;
    }
    return otherCodes.isEmpty ? null : otherCodes.first;
  }

  static bool _isOn(Object? value) => value == true || value == 1;
}
