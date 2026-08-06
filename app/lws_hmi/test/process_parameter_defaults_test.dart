import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_wire_codec.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_parameter_defaults.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';

void main() {
  ProcessPreset preset({
    ProcessType type = ProcessType.continuousWelding,
    double? swingWidth,
  }) {
    return ProcessPreset(
      uuid: 'u1',
      name: 'Test',
      kind: ProcessPresetKind.quick,
      source: 'test',
      isBuiltin: true,
      processType: type,
      materialType: MaterialType.stainlessSteel,
      thickness: type.isCleaning ? null : 2,
      gear: 1,
      parameters: ProcessParameters({
        'process.laser_power': 50,
        if (swingWidth != null) 'process.swing_width': swingWidth,
      }),
      createdAtMs: 1,
      updatedAtMs: 1,
    );
  }

  test('continuous welding missing swing width resolves to 2', () {
    final resolved = ProcessParameterDefaults.resolve(preset());
    expect(
      resolved.parameters.values['process.swing_width'],
      ProcessParameterDefaults.continuousWeldingSwingWidthMm,
    );
  });

  test('continuous welding zero swing width resolves to 2', () {
    final resolved = ProcessParameterDefaults.resolve(preset(swingWidth: 0));
    expect(resolved.parameters.values['process.swing_width'], 2);
  });

  test('continuous welding keeps non-zero swing width', () {
    final resolved = ProcessParameterDefaults.resolve(preset(swingWidth: 3.5));
    expect(resolved.parameters.values['process.swing_width'], 3.5);
  });

  test('spot welding zero swing width is left alone', () {
    final resolved = ProcessParameterDefaults.resolve(
      preset(type: ProcessType.spotWelding, swingWidth: 0),
    );
    expect(resolved.parameters.values['process.swing_width'], 0);
  });

  test('engineer draft from library applies continuous weld swing default', () {
    final draft = EngineerModeDraft.fromLibrary(preset(swingWidth: 0));
    expect(draft.preset.parameters.values['process.swing_width'], 2);
  });

  test('wire codec writes continuous weld swing default 2', () {
    final values = ProcessParameterWireCodec.buildWriteValues(
      preset: preset(swingWidth: 0),
      baseline: {
        for (final spec in ProcessParameterCatalog.specs) spec.key: 0.0,
      },
    );
    expect(values['process.swing_width'], 2);
  });
}
