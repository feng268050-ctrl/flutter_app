import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_parameter_visibility.dart';

void main() {
  ProcessPreset builtin() => ProcessPreset(
        uuid: 'eng-1',
        name: 'Stainless Steel-2mm',
        kind: ProcessPresetKind.engineerPreset,
        source: 'bundled',
        isBuiltin: true,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        materialName: 'Stainless Steel',
        thickness: 2,
        gear: 2,
        parameters: ProcessParameters({
          'process.laser_power': 55,
          'process.wire_feeding_speed': 10,
        }),
        createdAtMs: 1,
        updatedAtMs: 1,
      );

  ProcessPreset quick() => ProcessPreset(
        uuid: 'quick-1',
        name: 'Quick SS',
        kind: ProcessPresetKind.quick,
        source: 'bundled',
        isBuiltin: true,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.stainlessSteel,
        materialName: 'Stainless Steel',
        thickness: 1.5,
        gear: 1,
        parameters: ProcessParameters({
          'process.laser_power': 40,
        }),
        createdAtMs: 1,
        updatedAtMs: 1,
      );

  test('fromLibrary marks built-in read-only and not deletable', () {
    final draft = EngineerModeDraft.fromLibrary(builtin());
    expect(draft.isReadOnly, isTrue);
    expect(draft.canDelete, isFalse);
    expect(draft.unsaved, isFalse);
    expect(draft.isDirty, isFalse);
  });

  test('fromQuickSource creates unsaved user draft without DB uuid', () {
    final draft = EngineerModeDraft.fromQuickSource(quick());
    expect(draft.unsaved, isTrue);
    expect(draft.fromQuickHandoff, isTrue);
    expect(draft.isReadOnly, isFalse);
    expect(draft.preset.kind, ProcessPresetKind.user);
    expect(draft.preset.uuid, startsWith('draft-'));
    expect(draft.preset.parameters.values['process.laser_power'], 40);
  });

  test('editing draft marks dirty; reset restores baseline', () {
    final draft = EngineerModeDraft.fromLibrary(
      builtin().copyWith(
        kind: ProcessPresetKind.user,
        isBuiltin: false,
        source: 'user',
      ),
    );
    final edited = draft.copyWith(
      preset: draft.preset.copyWith(
        parameters: ProcessParameters({
          'process.laser_power': 70,
          'process.wire_feeding_speed': 10,
        }),
      ),
      unsaved: true,
    );
    expect(edited.isDirty, isTrue);
    final reset = edited.resetToBaseline();
    expect(reset.preset.parameters.values['process.laser_power'], 55);
  });

  test('visibility includes spot fields only for spot welding', () {
    expect(
      EngineerParameterVisibility.parameterKeysFor(ProcessType.spotWelding),
      contains('process.spot_welding_duration'),
    );
    expect(
      EngineerParameterVisibility.parameterKeysFor(
        ProcessType.continuousWelding,
      ),
      isNot(contains('process.spot_welding_duration')),
    );
    expect(
      EngineerParameterVisibility.parameterKeysFor(ProcessType.weldCleaning),
      isNot(contains('process.wire_feeding_speed')),
    );
    expect(
      EngineerParameterVisibility.showsThickness(ProcessType.weldCleaning),
      isFalse,
    );
  });

  test('continuous welding parameter order matches lws-ui T sequence', () {
    final keys = EngineerParameterVisibility.parameterKeysFor(
      ProcessType.continuousWelding,
    );
    expect(
      keys.indexOf('process.blowing_delay'),
      lessThan(keys.indexOf('process.power_ramp_up_duration')),
    );
    expect(
      keys.indexOf('process.power_ramp_up_duration'),
      lessThan(keys.indexOf('process.laser_power')),
    );
    expect(
      keys.indexOf('process.laser_power'),
      lessThan(keys.indexOf('process.power_ramp_down_duration')),
    );
    expect(
      keys.indexOf('process.power_ramp_down_duration'),
      lessThan(keys.indexOf('process.gas_off_delay')),
    );
  });
}
