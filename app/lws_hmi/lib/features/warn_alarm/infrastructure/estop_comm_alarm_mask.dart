/// Pure e-stop mask for Modbus alarm bits that must not frost-popup while the
/// machine e-stop is held.
///
/// - H022 / W001: bits may read true because hardware is de-energized
///   (lws-ui `applyEmergencyStopCommAlarmReset` parity).
/// - H029: laser emergency-stop alarm is an alarm-type dialog; product policy
///   shows it only after the machine e-stop button is reset (tip
///   "Device is in E-stop" is separate, on press).
abstract final class EstopCommAlarmMask {
  static const String emergencyStopAttr = 'machine.emergency_stop';
  static const String laserCommAttr = 'alarm.laser_comm';
  static const String wireFeederCommAttr = 'alarm.wire_feeder_comm';
  static const String laserEmergencyStopAttr = 'alarm.laser_emergency_stop';

  /// Attributes whose warn-signal active edge is suppressed while e-stop is
  /// active (effective = raw && !eStop).
  static bool isMaskedAttr(String id) =>
      id == laserCommAttr ||
      id == wireFeederCommAttr ||
      id == laserEmergencyStopAttr;

  /// Alias kept for existing call sites / tests.
  static bool isMaskedCommAttr(String id) => isMaskedAttr(id);

  /// Effective fault active: raw bit AND not e-stop.
  static bool effectiveActive({
    required bool raw,
    required bool eStopActive,
  }) =>
      raw && !eStopActive;
}
