import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_wire_codec.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

void main() {
  test('forces laser duty/frequency and piercing like lws-ui', () {
    final values = ProcessParameterWireCodec.buildWriteValues(
      preset: _preset(
        processType: ProcessType.continuousWelding,
        parameters: {
          'process.laser_power': 40,
          'process.swing_width': 2.0,
        },
      ),
      baseline: {
        for (final spec in ProcessParameterCatalog.specs) spec.key: 1.0,
      },
    );

    expect(values['process.laser_power'], 40);
    expect(values['process.laser_duty_cycle'], 100);
    expect(values['process.laser_frequency'], 5000);
    expect(values['process.piercing_power'], 40);
    expect(values['process.piercing_frequency'], 0);
    expect(values['process.piercing_duty_cycle'], 100);
    expect(values['process.wire_feeding_delay'], 0);
    expect(values['process.piercing_duration'], 0);
    expect(values['process.swing_width'], 2.0);
  });

  test('divides wide-cleaning swing width by 5 before HAL encode', () {
    final values = ProcessParameterWireCodec.buildWriteValues(
      preset: _preset(
        processType: ProcessType.wideCleaning,
        parameters: {
          'process.laser_power': 50,
          'process.swing_width': 20,
        },
      ),
      baseline: {
        for (final spec in ProcessParameterCatalog.specs) spec.key: 0.0,
      },
    );

    expect(values['process.swing_width'], 4.0);
  });
}

ProcessPreset _preset({
  required ProcessType processType,
  required Map<String, double> parameters,
}) {
  final now = DateTime.now().toUtc().millisecondsSinceEpoch;
  return ProcessPreset(
    uuid: 'wire-codec',
    name: 'Wire',
    kind: ProcessPresetKind.quick,
    source: 'test',
    isBuiltin: true,
    processType: processType,
    materialType: MaterialType.stainlessSteel,
    thickness: processType.isCleaning ? null : 1,
    gear: 1,
    parameters: ProcessParameters(parameters),
    createdAtMs: now,
    updatedAtMs: now,
  );
}
