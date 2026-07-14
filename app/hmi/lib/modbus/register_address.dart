/// Input / status register addresses mirrored from lws-ui (numeric parity only).
class DeviceStatusRegisterAddress {
  DeviceStatusRegisterAddress._();

  /// Control-card software version → Device Information "Firmware Version".
  static const int deviceSoftwareVersion = 0x0002;
}

/// Device-info block addresses mirrored from lws-ui `DeviceInfoRegisterAddress`.
class DeviceInfoRegisterAddress {
  DeviceInfoRegisterAddress._();

  static const int laserHardwareVersionHigh = 0x0030;
  static const int laserHardwareVersionLow = 0x0031;
  static const int laserSoftwareVersionHigh = 0x0032;
  static const int laserSoftwareVersionLow = 0x0033;
  static const int wireFeederHardwareVersion = 0x0034;
  static const int wireFeederSoftwareVersion = 0x0035;
  static const int gunHeadHardwareVersion = 0x0036;
  static const int gunHeadSoftwareVersion = 0x0037;
  static const int gunHeadSnHigh = 0x0038;
  static const int gunHeadSnLow = 0x0039;
}

/// Device-data temperatures shown on Monitor → Alarm Information (welding gun).
///
/// Addresses mirrored from lws-ui `DeviceDataRegisterAddress`. Note: lws-ui names
/// `0x0061` as `GUN_MOTOR_CURRENT` but comments + UI treat it as gun motor temperature.
class DeviceDataRegisterAddress {
  DeviceDataRegisterAddress._();

  /// Gun motor temperature (lws-ui misnamed `GUN_MOTOR_CURRENT`).
  static const int gunMotorTemperature = 0x0061;
  static const int gunMotorDriveTemperature = 0x0062;
  static const int protectiveCoverTemperature = 0x0063;
  static const int collimatorTemperature = 0x0064;
}
