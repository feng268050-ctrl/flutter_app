import 'package:lws_hmi/features/settings/application/advanced_settings_modbus_ids.dart';

/// Wire ↔ UI encoding for Advanced Settings thresholds (lws-ui
/// `ModbusFiledBuilder.doCreateWriteDeviceSetting` parity).
///
/// Temps / recovery use catalog `scale: 0.1` via HAL — pass engineering units.
abstract final class AdvancedSettingsThresholdCodec {
  static const zeroPointFactor = 10;
  static const laserPowerFactor = 100;
  static const swingWidthOffset = 75;

  static Object? toWire(String attributeId, double ui) {
    switch (attributeId) {
      case AdvancedSettingsModbusIds.zeroPointCorrection:
        return (ui * zeroPointFactor).round();
      case AdvancedSettingsModbusIds.swingWidthCorrection:
        final shifted = ui.round() + swingWidthOffset;
        return shifted == 0 ? 1 : shifted;
      case AdvancedSettingsModbusIds.laserStartPower:
      case AdvancedSettingsModbusIds.laserEndPower:
        return (ui * laserPowerFactor).round();
      case AdvancedSettingsModbusIds.blowingPressureThreshold:
        return ui.round();
      case AdvancedSettingsModbusIds.motorTempAlarmThreshold:
      case AdvancedSettingsModbusIds.driverTempAlarmThreshold:
      case AdvancedSettingsModbusIds.protectiveLensTempAlarmThreshold:
      case AdvancedSettingsModbusIds.collimatingLensTempAlarmThreshold:
      case AdvancedSettingsModbusIds.tempAlarmRecoveryInterval:
        // Catalog scale 0.1 — HAL encodes engineering → raw.
        return ui;
      default:
        return ui.round();
    }
  }

  static double? fromWire(String attributeId, Object? value) {
    if (value == null) {
      return null;
    }
    final n = value is num ? value.toDouble() : double.tryParse('$value');
    if (n == null) {
      return null;
    }
    switch (attributeId) {
      case AdvancedSettingsModbusIds.zeroPointCorrection:
        return n / zeroPointFactor;
      case AdvancedSettingsModbusIds.swingWidthCorrection:
        return n - swingWidthOffset;
      case AdvancedSettingsModbusIds.laserStartPower:
      case AdvancedSettingsModbusIds.laserEndPower:
        return n / laserPowerFactor;
      default:
        return n;
    }
  }
}
