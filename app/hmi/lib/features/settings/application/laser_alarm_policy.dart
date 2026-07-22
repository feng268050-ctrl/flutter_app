/// Pure laser-enable / work-block policy mirroring lws-ui
/// `LaserEnableAlarmGuard` (no Flutter / HAL dependencies).
///
/// Bypassable coded alarms: A001 (gas), C002 (camera), L001 (lens),
/// W001/W002 (feeder). All other coded alarms always block enable/ready
/// unless [LaserAlarmPolicySnapshot.keepLaserOnWhileAlarmed] applies to
/// runtime work interrupt only.
abstract final class LaserAlarmPolicy {
  static const alarmA001 = 'A001';
  static const alarmC002 = 'C002';
  static const alarmL001 = 'L001';
  static const alarmW001 = 'W001';
  static const alarmW002 = 'W002';

  static bool isBypassableAlarmCode(String? code) {
    return code == alarmA001 ||
        code == alarmC002 ||
        code == alarmL001 ||
        code == alarmW001 ||
        code == alarmW002;
  }

  static bool isGasBlocking({
    required bool gasAlarmActive,
    required bool allowWorkAfterGasAlarm,
  }) =>
      gasAlarmActive && !allowWorkAfterGasAlarm;

  static bool isCameraBlocking({
    required bool cameraAlarmActive,
    required bool allowWorkAfterCameraAlarm,
  }) =>
      cameraAlarmActive && !allowWorkAfterCameraAlarm;

  static bool isLensBlocking({
    required bool lensAlarmActive,
    required bool allowWorkAfterLensContamination,
  }) =>
      lensAlarmActive && !allowWorkAfterLensContamination;

  static bool isFeederBlocking({
    required bool feederAlarmActive,
    required bool allowWorkAfterFeederAlarm,
  }) =>
      feederAlarmActive && !allowWorkAfterFeederAlarm;

  /// Ready/LED path: respects allow-* only; ignores keepLaserOnWhileAlarmed.
  static bool isReadyIndicatorBlocked({
    required bool gasBlocking,
    required bool cameraBlocking,
    required bool lensBlocking,
    required bool feederBlocking,
    required bool otherCodedWarnBlocking,
  }) =>
      gasBlocking ||
      cameraBlocking ||
      lensBlocking ||
      feederBlocking ||
      otherCodedWarnBlocking;

  /// Runtime work interrupt: keepLaserOnWhileAlarmed bypasses all coded blocks.
  static bool isWorkBlocked({
    required bool keepLaserOnWhileAlarmed,
    required bool readyIndicatorBlocked,
  }) {
    if (keepLaserOnWhileAlarmed) {
      return false;
    }
    return readyIndicatorBlocked;
  }

  /// Other (non-bypassable) coded warn blocks laser-enable unless keep-on.
  static bool otherCodedBlocksLaserEnable({
    required bool otherCodedWarnActive,
    required bool keepLaserOnWhileAlarmed,
  }) =>
      otherCodedWarnActive && !keepLaserOnWhileAlarmed;

  /// When a bypassable alarm is allowed, presentation may use INFO vs WARN.
  static bool treatBypassableAsInfo({
    required String? code,
    required LaserAlarmPolicySnapshot snapshot,
  }) {
    if (!isBypassableAlarmCode(code)) {
      return false;
    }
    switch (code) {
      case alarmA001:
        return snapshot.allowWorkAfterGasAlarm;
      case alarmC002:
        return snapshot.allowWorkAfterCameraAlarm;
      case alarmL001:
        return snapshot.allowWorkAfterLensContamination;
      case alarmW001:
      case alarmW002:
        return snapshot.allowWorkAfterFeederAlarm;
      default:
        return false;
    }
  }
}

/// Snapshot of dangerous-ops flags for policy helpers.
final class LaserAlarmPolicySnapshot {
  const LaserAlarmPolicySnapshot({
    required this.keepLaserOnWhileAlarmed,
    required this.allowWorkAfterCameraAlarm,
    required this.allowWorkAfterGasAlarm,
    required this.allowWorkAfterLensContamination,
    required this.allowWorkAfterFeederAlarm,
  });

  final bool keepLaserOnWhileAlarmed;
  final bool allowWorkAfterCameraAlarm;
  final bool allowWorkAfterGasAlarm;
  final bool allowWorkAfterLensContamination;
  final bool allowWorkAfterFeederAlarm;
}
