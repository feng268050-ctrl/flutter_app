/// Known Advanced Settings Modbus attribute ids from `assets/hal/modbus.json`.
///
/// Threshold UI may watch/write these via HAL when product wiring lands.
/// AI / dangerous toggles are **not** Modbus — see [AdvancedSettingsStore].
abstract final class AdvancedSettingsModbusIds {
  static const zeroPointCorrection = 'setting.zero_point_correction';
  static const laserStartPower = 'setting.laser_start_power';
  static const laserEndPower = 'setting.laser_end_power';
  static const motorTempAlarmThreshold = 'setting.motor_temp_alarm_threshold';
  static const driverTempAlarmThreshold =
      'setting.driver_temp_alarm_threshold';
  static const protectiveLensTempAlarmThreshold =
      'setting.protective_lens_temp_alarm_threshold';
  static const collimatingLensTempAlarmThreshold =
      'setting.collimating_lens_temp_alarm_threshold';
  static const tempAlarmRecoveryInterval =
      'setting.temp_alarm_recovery_interval';
}
