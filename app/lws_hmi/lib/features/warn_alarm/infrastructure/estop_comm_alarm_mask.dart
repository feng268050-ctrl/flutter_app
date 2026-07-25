/// Pure e-stop mask for laser / wire-feeder communication alarm bits.
///
/// While machine e-stop is latched, those Modbus bits may read true because
/// hardware is de-energized; product policy treats them as inactive on the
/// App alarm path (lws-ui `applyEmergencyStopCommAlarmReset` parity).
abstract final class EstopCommAlarmMask {
  static const String emergencyStopAttr = 'machine.emergency_stop';
  static const String laserCommAttr = 'alarm.laser_comm';
  static const String wireFeederCommAttr = 'alarm.wire_feeder_comm';

  /// Attributes whose active edge is suppressed while e-stop is active.
  static bool isMaskedCommAttr(String id) =>
      id == laserCommAttr || id == wireFeederCommAttr;

  /// Effective fault active for H022 / W001: raw bit AND not e-stop.
  static bool effectiveActive({
    required bool raw,
    required bool eStopActive,
  }) =>
      raw && !eStopActive;
}
