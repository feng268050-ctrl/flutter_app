/// Stable Modbus attribute ids from [HmiHalAssets.modbus] (`assets/hal/modbus.json`).
///
/// Prefer these over hard-coded register addresses.
class ModbusAttributeId {
  ModbusAttributeId._();

  static const String deviceControlCardVersion = 'device.control_card_version';
  static const String deviceLaserHwVersion = 'device.laser_hw_version';
  static const String deviceLaserSwVersion = 'device.laser_sw_version';
  static const String deviceWireFeederHwVersion =
      'device.wire_feeder_hw_version';
  static const String deviceWireFeederSwVersion =
      'device.wire_feeder_sw_version';
  static const String deviceGunHeadHwVersion = 'device.gun_head_hw_version';
  static const String deviceGunHeadSwVersion = 'device.gun_head_sw_version';
  static const String deviceGunHeadSn = 'device.gun_head_sn';

  static const String telemetryGunMotorTemp = 'telemetry.gun_motor_temp';
  static const String telemetryGunMotorDriveTemp =
      'telemetry.gun_motor_drive_temp';
  static const String telemetryProtectiveCoverTemp =
      'telemetry.protective_cover_temp';
  static const String telemetryCollimatorTemp = 'telemetry.collimator_temp';

  static const String alarmLaserComm = 'alarm.laser_comm';
  static const String alarmGunComm = 'alarm.gun_comm';
  static const String alarmGunMotorOverTemp = 'alarm.gun_motor_over_temp';
  static const String alarmDriverOverTemp = 'alarm.driver_over_temp';
  static const String alarmProtectiveMirrorOverTemp =
      'alarm.protective_mirror_over_temp';
  static const String alarmCollimatorOverTemp = 'alarm.collimator_over_temp';
  static const String alarmWireFeederComm = 'alarm.wire_feeder_comm';
  static const String alarmShieldingGasBlowPressure =
      'alarm.shielding_gas_blow_pressure';
}
