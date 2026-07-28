import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/gpio/gpio_led_controller.dart';

/// Pure RGB GPIO desired-state predicates (lws-ui `RgbLedDecision`).
///
/// Red = laser; yellow = alarm; green = ready.
abstract final class RgbLedDecision {
  /// Red: emit steady; H022 offline off; else standby blink.
  /// No device status ([primed] false) → off (lws-ui `deviceStatus == null`).
  static IndicatorMode redMode({
    required bool primed,
    required bool laserOn,
    required bool laserCommAlarm,
  }) {
    if (!primed) {
      return IndicatorMode.off;
    }
    if (laserOn) {
      return IndicatorMode.steadyOn;
    }
    if (laserCommAlarm) {
      return IndicatorMode.off;
    }
    return IndicatorMode.blink;
  }

  /// Yellow blinks when any active coded alarm is WARN-severity for yellow.
  ///
  /// Parity with `WarnDialogSeverity.hasAnyActiveWarnSeverityAlarm`:
  /// - Bypassable A001/C002/L001/W*: INFO when allow-* ON → those codes alone
  ///   do not blink yellow (except A001 still blinks via hardware — A001 is
  ///   treated as non-bypassable for **yellow hardware** below).
  /// - Non-feeder / non-camera / non-lens coded faults (H/E/C001/A001/…) always
  ///   blink yellow while active (hardware-segment parity), even if dialog is
  ///   INFO for A001 bypass.
  static IndicatorMode yellowMode({required bool hasWarnSeverityAlarm}) {
    return hasWarnSeverityAlarm ? IndicatorMode.blink : IndicatorMode.off;
  }

  /// Green ready: CNC uses `cncConnected`; other modes need enable + clamp.
  /// [keepLaserOnWhileAlarmed] does **not** clear [readyIndicatorBlocked].
  static IndicatorMode greenMode({
    required bool primed,
    required bool laserOn,
    required bool keySwitchOn,
    required bool readyIndicatorBlocked,
    required bool laserEnableActive,
    required bool safetyGroundLockLocked,
    required bool cncMode,
    required bool cncConnected,
  }) {
    if (!primed || laserOn || readyIndicatorBlocked || !keySwitchOn) {
      return IndicatorMode.off;
    }
    if (cncMode) {
      return cncConnected ? IndicatorMode.steadyOn : IndicatorMode.off;
    }
    if (laserEnableActive && safetyGroundLockLocked) {
      return IndicatorMode.steadyOn;
    }
    return IndicatorMode.off;
  }

  /// Yellow WARN set (lws-ui yellow rules, not dialog INFO alone).
  ///
  /// - Codes that map to gun/laser/control hardware (everything except
  ///   C002/L001/W001/W002): always yellow while fault-active.
  /// - C002/L001/W001/W002: yellow only when not demoted to INFO by allow-*.
  static bool hasAnyActiveWarnSeverity({
    required Iterable<String> activeCodes,
    required LaserAlarmPolicySnapshot snapshot,
  }) {
    for (final code in activeCodes) {
      if (_yellowAlwaysWhenActive(code)) {
        return true;
      }
      if (LaserAlarmPolicy.isBypassableAlarmCode(code) &&
          !LaserAlarmPolicy.treatBypassableAsInfo(
            code: code,
            snapshot: snapshot,
          )) {
        return true;
      }
    }
    return false;
  }

  /// A001 is bypassable for dialog/green, but control-card gas bits still count
  /// as non-feeder hardware for yellow (lws-ui `hasNonFeederHardwareAlarm`).
  static bool _yellowAlwaysWhenActive(String code) {
    if (code == LaserAlarmPolicy.alarmA001) {
      return true;
    }
    return code != LaserAlarmPolicy.alarmC002 &&
        code != LaserAlarmPolicy.alarmL001 &&
        code != LaserAlarmPolicy.alarmW001 &&
        code != LaserAlarmPolicy.alarmW002;
  }

  /// Ready/green block stack from active coded alarms + bypass snapshot.
  static bool readyIndicatorBlockedFromActive({
    required Set<String> activeCodes,
    required LaserAlarmPolicySnapshot snapshot,
  }) {
    final gas = activeCodes.contains(LaserAlarmPolicy.alarmA001);
    final camera = activeCodes.contains(LaserAlarmPolicy.alarmC002);
    final lens = activeCodes.contains(LaserAlarmPolicy.alarmL001);
    final feeder = activeCodes.contains(LaserAlarmPolicy.alarmW001) ||
        activeCodes.contains(LaserAlarmPolicy.alarmW002);
    final other =
        activeCodes.any((c) => !LaserAlarmPolicy.isBypassableAlarmCode(c));
    return LaserAlarmPolicy.isReadyIndicatorBlocked(
      gasBlocking: LaserAlarmPolicy.isGasBlocking(
        gasAlarmActive: gas,
        allowWorkAfterGasAlarm: snapshot.allowWorkAfterGasAlarm,
      ),
      cameraBlocking: LaserAlarmPolicy.isCameraBlocking(
        cameraAlarmActive: camera,
        allowWorkAfterCameraAlarm: snapshot.allowWorkAfterCameraAlarm,
      ),
      lensBlocking: LaserAlarmPolicy.isLensBlocking(
        lensAlarmActive: lens,
        allowWorkAfterLensContamination:
            snapshot.allowWorkAfterLensContamination,
      ),
      feederBlocking: LaserAlarmPolicy.isFeederBlocking(
        feederAlarmActive: feeder,
        allowWorkAfterFeederAlarm: snapshot.allowWorkAfterFeederAlarm,
      ),
      otherCodedWarnBlocking: other,
    );
  }
}
