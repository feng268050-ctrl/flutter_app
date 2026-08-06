import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Process-parameter product defaults (lws-ui `DefaultValueUtils` /
/// `createWeldingModelProcessParametersData` + L1 Pro process-library).
abstract final class ProcessParameterDefaults {
  /// Continuous welding default swing width (mm).
  ///
  /// Process-library continuous-weld rows ship `process.swing_width = 2`;
  /// lws-ui welding-model default is also 2mm (not the 2.5 leftover in
  /// `createDefaultProcessParametersData`).
  static const continuousWeldingSwingWidthMm = 2.0;

  /// Fills missing / zeroed continuous-weld swing width so Quick / Engineer
  /// UI and Modbus apply agree on the product default.
  static ProcessPreset resolve(ProcessPreset preset) {
    if (preset.processType != ProcessType.continuousWelding) {
      return preset;
    }
    final swing = preset.parameters.values['process.swing_width'];
    if (swing != null && swing > 0) {
      return preset;
    }
    final values = Map<String, double>.from(preset.parameters.values)
      ..['process.swing_width'] = continuousWeldingSwingWidthMm;
    return preset.copyWith(parameters: ProcessParameters(values));
  }
}
