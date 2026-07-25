import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_resolver.dart';

void main() {
  tearDown(QuickModeSelectionCarry.clear);

  ProcessPreset row({
    required int gear,
    required double thickness,
    MaterialType material = MaterialType.stainlessSteel,
    double? swingWidth,
    ProcessType processType = ProcessType.continuousWelding,
  }) {
    return ProcessPreset(
      uuid: 'g$gear-t$thickness-s$swingWidth',
      name: 'row',
      kind: ProcessPresetKind.quick,
      source: 'test',
      isBuiltin: true,
      processType: processType,
      materialType: material,
      materialName: material.englishName,
      thickness: swingWidth == null ? thickness : null,
      gear: gear,
      parameters: ProcessParameters({
        'process.laser_power': 50,
        if (swingWidth != null) 'process.swing_width': swingWidth,
      }),
      createdAtMs: 1,
      updatedAtMs: 1,
    );
  }

  test('preferCarryThenLocal carry wins then falls back', () {
    expect(QuickModeSelectionResolver.preferCarryThenLocal(3, 1), 3);
    expect(QuickModeSelectionResolver.preferCarryThenLocal<int>(null, 1), 1);
  });

  test('resolveDimension inherits matching thickness for gear', () {
    final rows = [
      row(gear: 1, thickness: 0.5),
      row(gear: 1, thickness: 1.0),
      row(gear: 3, thickness: 1.0),
      row(gear: 3, thickness: 2.0),
    ];
    final index = QuickModeSelectionResolver.resolveDimensionIndex(
      dimensionList: const [0.5, 1.0, 2.0],
      dataList: rows,
      materialType: MaterialType.stainlessSteel,
      gear: 3,
      preferred: 2.0,
      swingWidth: false,
    );
    expect(index, 2);
  });

  test('resolveDimension missing thickness falls back to first for gear', () {
    final rows = [
      row(gear: 1, thickness: 0.5),
      row(gear: 1, thickness: 1.0),
      row(gear: 3, thickness: 2.0),
    ];
    final index = QuickModeSelectionResolver.resolveDimensionIndex(
      dimensionList: const [0.5, 1.0, 2.0],
      dataList: rows,
      materialType: MaterialType.stainlessSteel,
      gear: 1,
      preferred: 2.0,
      swingWidth: false,
    );
    expect(index, 0);
  });

  test('resolveDimension thickness present but not for gear falls back', () {
    final rows = [
      row(gear: 1, thickness: 0.5),
      row(gear: 3, thickness: 1.0),
      row(gear: 3, thickness: 2.0),
    ];
    final index = QuickModeSelectionResolver.resolveDimensionIndex(
      dimensionList: const [0.5, 1.0, 2.0],
      dataList: rows,
      materialType: MaterialType.stainlessSteel,
      gear: 3,
      preferred: 0.5,
      swingWidth: false,
    );
    expect(index, 1);
  });

  test('builder inherits carry gear and thickness across resolve', () {
    QuickModeSelectionCarry.remember(
      material: MaterialType.stainlessSteel.storageValue,
      gearValue: 3,
      thicknessValue: 2.0,
    );
    final rows = [
      row(gear: 1, thickness: 0.5),
      row(gear: 1, thickness: 1.0),
      row(gear: 3, thickness: 1.0),
      row(gear: 3, thickness: 2.0),
    ];
    final selection = QuickModeSelectionBuilder.resolve(
      rows: rows,
      processType: ProcessType.continuousWelding,
    );
    expect(selection.gear, 3);
    expect(selection.dimension, 2.0);
    expect(selection.matched?.gear, 3);
    expect(selection.matched?.thickness, 2.0);
  });

  test('builder uses swing width for cleaning modes', () {
    QuickModeSelectionCarry.remember(
      material: MaterialType.stainlessSteel.storageValue,
      gearValue: 2,
      swingWidthValue: 20,
    );
    final rows = [
      row(
        gear: 1,
        thickness: 0,
        swingWidth: 10,
        processType: ProcessType.weldCleaning,
      ),
      row(
        gear: 2,
        thickness: 0,
        swingWidth: 20,
        processType: ProcessType.weldCleaning,
      ),
      row(
        gear: 2,
        thickness: 0,
        swingWidth: 30,
        processType: ProcessType.weldCleaning,
      ),
    ];
    final selection = QuickModeSelectionBuilder.resolve(
      rows: rows,
      processType: ProcessType.weldCleaning,
    );
    expect(selection.useSwingWidth, isTrue);
    expect(selection.gear, 2);
    expect(selection.dimension, 20);
    expect(
      selection.matched?.parameters.values['process.swing_width'],
      20,
    );
  });

  test('gear-only change can leave unmatched pair', () {
    final rows = [
      row(gear: 1, thickness: 0.5),
      row(gear: 3, thickness: 2.0),
    ];
    final current = QuickModeSelection(
      materials: const [MaterialType.stainlessSteel],
      gears: const [1, 3],
      dimensions: const [0.5, 2.0],
      material: MaterialType.stainlessSteel,
      gear: 1,
      dimension: 0.5,
      useSwingWidth: false,
      matched: rows.first,
    );
    final next = QuickModeSelectionBuilder.withGear(
      current: current,
      rows: rows,
      gear: 3,
    );
    expect(next.gear, 3);
    expect(next.dimension, 0.5);
    expect(next.matched, isNull);
  });
}
