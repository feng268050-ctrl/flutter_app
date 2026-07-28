import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Maps library/UI process values onto Modbus engineering units for apply.
///
/// Parity with lws-ui `ModbusFiledBuilder.createProcessParametersData` /
/// `encodeSwingWidthRegister` (power still uses catalog `%` + HAL `scale`).
abstract final class ProcessParameterWireCodec {
  /// Laser duty / piercing duty forced to 100% (wire → 10000 with scale 0.01).
  static const forcedDutyCyclePercent = 100.0;

  /// Laser frequency forced to 5000 Hz.
  static const forcedLaserFrequencyHz = 5000.0;

  /// Piercing frequency forced to 0 Hz.
  static const forcedPiercingFrequencyHz = 0.0;

  /// Wide-cleaning UI swing width is divided by 5 before HAL scale 0.1 encode.
  static const wideCleaningSwingDivisor = 5.0;

  /// Builds the full `process` group map to write (baseline ∪ preset ∪ forces).
  static Map<String, double> buildWriteValues({
    required ProcessPreset preset,
    required Map<String, double> baseline,
  }) {
    final values = <String, double>{
      ...baseline,
      ...preset.parameters.values,
    };

    final laserPower = values['process.laser_power'] ?? 0;
    values['process.laser_power'] = laserPower;
    values['process.laser_duty_cycle'] = forcedDutyCyclePercent;
    values['process.laser_frequency'] = forcedLaserFrequencyHz;
    values['process.piercing_power'] = laserPower;
    values['process.piercing_frequency'] = forcedPiercingFrequencyHz;
    values['process.piercing_duty_cycle'] = forcedDutyCyclePercent;

    if (preset.processType == ProcessType.wideCleaning) {
      final swing = values['process.swing_width'] ?? 0;
      values['process.swing_width'] = swing / wideCleaningSwingDivisor;
    }

    return values;
  }
}
