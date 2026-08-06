import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/engineer_mode_session_store.dart';
import 'package:lws_hmi/features/process_mode/domain/engineer_mode_draft.dart';

void main() {
  tearDown(EngineerModeSessionStore.instance.clearForTest);

  test('put/get survives across process types', () {
    final weld = EngineerModeDraft.fromLibrary(
      ProcessPreset(
        uuid: 'w1',
        name: 'Weld',
        kind: ProcessPresetKind.engineerPreset,
        source: 'test',
        isBuiltin: true,
        processType: ProcessType.continuousWelding,
        parameters: ProcessParameters({
          'process.swing_width': 3.5,
        }),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );
    final cut = EngineerModeDraft.fromLibrary(
      ProcessPreset(
        uuid: 'c1',
        name: 'Cut',
        kind: ProcessPresetKind.engineerPreset,
        source: 'test',
        isBuiltin: true,
        processType: ProcessType.handCutting,
        parameters: ProcessParameters({
          'process.laser_power': 80,
        }),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );

    EngineerModeSessionStore.instance.put(weld);
    EngineerModeSessionStore.instance.put(cut);

    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .parameters
          .values['process.swing_width'],
      3.5,
    );
    expect(
      EngineerModeSessionStore.instance.get(ProcessType.handCutting)?.preset.name,
      'Cut',
    );
  });

  test('edited draft replaces prior cache entry for same type', () {
    final base = EngineerModeDraft.fromLibrary(
      ProcessPreset(
        uuid: 'w1',
        name: 'Weld',
        kind: ProcessPresetKind.engineerPreset,
        source: 'test',
        isBuiltin: false,
        processType: ProcessType.continuousWelding,
        parameters: ProcessParameters({
          'process.swing_width': 2.0,
        }),
        createdAtMs: 1,
        updatedAtMs: 1,
      ),
    );
    EngineerModeSessionStore.instance.put(base);
    final edited = base.copyWith(
      unsaved: true,
      preset: base.preset.copyWith(
        parameters: ProcessParameters({
          'process.swing_width': 4.5,
        }),
      ),
    );
    EngineerModeSessionStore.instance.put(edited);

    expect(
      EngineerModeSessionStore.instance
          .get(ProcessType.continuousWelding)
          ?.preset
          .parameters
          .values['process.swing_width'],
      4.5,
    );
    expect(
      EngineerModeSessionStore.instance.get(ProcessType.continuousWelding)?.unsaved,
      isTrue,
    );
  });
}
