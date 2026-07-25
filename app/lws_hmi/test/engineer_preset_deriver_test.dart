import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/application/engineer_preset_deriver.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

void main() {
  group('EngineerPresetDeriver', () {
    test('pickMedianQuickPreset selects middle gear and thickness', () {
      final rows = [
        _quick(gear: 1, thickness: 1, power: 10),
        _quick(gear: 2, thickness: 1, power: 20),
        _quick(gear: 2, thickness: 2, power: 30),
        _quick(gear: 2, thickness: 3, power: 40),
        _quick(gear: 3, thickness: 3, power: 50),
      ];

      final picked = EngineerPresetDeriver.pickMedianQuickPreset(
        rows,
        processType: ProcessType.continuousWelding,
      );

      expect(picked, isNotNull);
      expect(picked!.gear, 2);
      expect(picked.thickness, 2);
      expect(picked.parameters.values['process.laser_power'], 30);
    });

    test('pickMedianQuickPreset uses swing width for clean modes', () {
      final rows = [
        _quickClean(gear: 1, swingWidth: 10, power: 100),
        _quickClean(gear: 2, swingWidth: 20, power: 200),
        _quickClean(gear: 2, swingWidth: 30, power: 300),
        _quickClean(gear: 3, swingWidth: 30, power: 400),
      ];

      final picked = EngineerPresetDeriver.pickMedianQuickPreset(
        rows,
        processType: ProcessType.weldCleaning,
      );

      expect(picked, isNotNull);
      expect(picked!.gear, 2);
      expect(picked.parameters.values['process.swing_width'], 20);
    });

    test('cloneAsEngineerPreset uses English material name', () {
      final source = _quick(
        gear: 2,
        thickness: 2,
        power: 55,
        processType: ProcessType.spotWelding,
      );

      final clone = EngineerPresetDeriver.cloneAsEngineerPreset(
        source,
        libraryVersion: '1.0.4-beta',
        nowMs: 1,
      );

      expect(clone.kind, ProcessPresetKind.engineerPreset);
      expect(clone.name, 'Stainless Steel-2mm');
      expect(clone.id, isNull);
      expect(clone.isBuiltin, isTrue);
      expect(clone.parameters.values['process.laser_power'], 55);
    });

    test('pickMedianQuickPreset filters by material type', () {
      final rows = [
        _quick(
          gear: 1,
          thickness: 1,
          power: 10,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 2,
          thickness: 2,
          power: 20,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 1,
          thickness: 3,
          power: 30,
          material: MaterialType.carbonSteel,
        ),
        _quick(
          gear: 2,
          thickness: 4,
          power: 40,
          material: MaterialType.carbonSteel,
        ),
      ];

      final picked = EngineerPresetDeriver.pickMedianQuickPreset(
        rows,
        processType: ProcessType.continuousWelding,
        materialType: MaterialType.carbonSteel,
      );

      expect(picked!.materialType, MaterialType.carbonSteel);
      expect(picked.gear, 1);
      expect(picked.thickness, 3);
      expect(picked.parameters.values['process.laser_power'], 30);
    });

    test('withDerivedEngineerPresets adds one preset per material', () {
      final rows = [
        _quick(
          gear: 1,
          thickness: 1,
          power: 10,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 2,
          thickness: 2,
          power: 20,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 1,
          thickness: 3,
          power: 30,
          material: MaterialType.carbonSteel,
        ),
        _quick(
          gear: 2,
          thickness: 4,
          power: 40,
          material: MaterialType.carbonSteel,
        ),
        _quick(
          gear: 2,
          thickness: 5,
          power: 50,
          material: MaterialType.custom,
          materialName: 'Special',
        ),
      ];

      final merged = EngineerPresetDeriver.withDerivedEngineerPresets(
        rows,
        libraryVersion: '1.0.0',
        nowMs: 1,
      );

      final engineers = merged
          .where((preset) => preset.kind == ProcessPresetKind.engineerPreset)
          .toList();
      expect(engineers, hasLength(2));
      expect(
        engineers.where((p) => p.materialType == MaterialType.stainlessSteel),
        hasLength(1),
      );
      expect(
        engineers.where((p) => p.materialType == MaterialType.carbonSteel),
        hasLength(1),
      );
    });

    test('explicit engineer presets are not replaced by derived rows', () {
      final explicit = _quick(
        gear: 1,
        thickness: 1,
        power: 99,
        material: MaterialType.stainlessSteel,
      ).copyWith(
        uuid: 'explicit-engineer',
        name: 'Explicit Stainless',
        kind: ProcessPresetKind.engineerPreset,
      );
      final rows = [
        _quick(
          gear: 1,
          thickness: 1,
          power: 10,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 2,
          thickness: 2,
          power: 20,
          material: MaterialType.stainlessSteel,
        ),
        explicit,
      ];

      final merged = EngineerPresetDeriver.withDerivedEngineerPresets(
        rows,
        libraryVersion: '1.0.0',
        nowMs: 1,
      );
      final engineers = merged
          .where((preset) => preset.kind == ProcessPresetKind.engineerPreset)
          .toList();

      expect(engineers, hasLength(1));
      expect(engineers.single.uuid, 'explicit-engineer');
      expect(engineers.single.parameters.values['process.laser_power'], 99);
    });

    test('withDerivedEngineerPresets covers each process type and material', () {
      final rows = [
        _quick(
          gear: 1,
          thickness: 1,
          power: 10,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 2,
          thickness: 2,
          power: 20,
          material: MaterialType.stainlessSteel,
        ),
        _quick(
          gear: 1,
          thickness: 3,
          power: 30,
          material: MaterialType.carbonSteel,
        ),
        _quick(
          gear: 1,
          thickness: 1,
          power: 15,
          material: MaterialType.stainlessSteel,
          processType: ProcessType.handCutting,
        ),
      ];

      final merged = EngineerPresetDeriver.withDerivedEngineerPresets(
        rows,
        libraryVersion: '1.0.0',
        nowMs: 1,
      );
      final engineers = merged
          .where((preset) => preset.kind == ProcessPresetKind.engineerPreset)
          .toList();

      expect(merged, hasLength(7));
      expect(engineers, hasLength(3));
      expect(
        engineers
            .where((preset) => preset.processType == ProcessType.handCutting)
            .single
            .name,
        'Stainless Steel-1mm',
      );
    });
  });
}

ProcessPreset _quick({
  required int gear,
  required double thickness,
  required double power,
  MaterialType material = MaterialType.stainlessSteel,
  String? materialName,
  ProcessType processType = ProcessType.continuousWelding,
}) {
  return ProcessPreset(
    uuid: 'quick-$gear-$thickness-$power-${material.storageValue}',
    name: 'quick',
    kind: ProcessPresetKind.quick,
    source: 'bundled',
    isBuiltin: true,
    processType: processType,
    materialType: material,
    materialName: materialName,
    thickness: thickness,
    gear: gear,
    parameters: ProcessParameters({'process.laser_power': power}),
    libraryVersion: '1.0.0',
    createdAtMs: 1,
    updatedAtMs: 1,
  );
}

ProcessPreset _quickClean({
  required int gear,
  required double swingWidth,
  required double power,
}) {
  return ProcessPreset(
    uuid: 'clean-$gear-$swingWidth-$power',
    name: 'clean',
    kind: ProcessPresetKind.quick,
    source: 'bundled',
    isBuiltin: true,
    processType: ProcessType.weldCleaning,
    materialType: MaterialType.stainlessSteel,
    thickness: null,
    gear: gear,
    parameters: ProcessParameters({
      'process.laser_power': power,
      'process.swing_width': swingWidth,
      'process.swing_frequency': 100,
    }),
    libraryVersion: '1.0.0',
    createdAtMs: 1,
    updatedAtMs: 1,
  );
}
