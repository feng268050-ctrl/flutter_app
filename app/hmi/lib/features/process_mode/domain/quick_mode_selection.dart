import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_carry.dart';
import 'package:lws_hmi/features/process_mode/domain/quick_mode_selection_resolver.dart';

/// Resolved Quick Mode picker state for one process type.
final class QuickModeSelection {
  const QuickModeSelection({
    required this.materials,
    required this.gears,
    required this.dimensions,
    required this.material,
    required this.gear,
    required this.dimension,
    required this.useSwingWidth,
    required this.matched,
  });

  final List<MaterialType> materials;
  final List<int> gears;
  final List<double> dimensions;
  final MaterialType? material;
  final int? gear;
  final double? dimension;
  final bool useSwingWidth;
  final ProcessPreset? matched;

  double? get thickness => useSwingWidth ? null : dimension;
  double? get swingWidth => useSwingWidth ? dimension : null;
}

/// Builds gear / dimension lists and applies carry inherit / fallback.
abstract final class QuickModeSelectionBuilder {
  static List<MaterialType> materialsOf(List<ProcessPreset> rows) {
    final seen = <MaterialType>{};
    final out = <MaterialType>[];
    for (final row in rows) {
      final material = row.materialType;
      if (material == null || material == MaterialType.custom) {
        continue;
      }
      if (seen.add(material)) {
        out.add(material);
      }
    }
    return out;
  }

  static List<int> gearsOf(
    List<ProcessPreset> rows,
    MaterialType? material,
  ) {
    final seen = <int>{};
    final out = <int>[];
    for (final row in rows) {
      if (row.materialType != material || row.gear == null) {
        continue;
      }
      if (seen.add(row.gear!)) {
        out.add(row.gear!);
      }
    }
    return out;
  }

  /// Unique thicknesses or swing widths for [material] (not filtered by gear).
  static List<double> dimensionsOf(
    List<ProcessPreset> rows, {
    required MaterialType? material,
    required bool swingWidth,
  }) {
    final seen = <double>{};
    final out = <double>[];
    for (final row in rows) {
      if (row.materialType != material) {
        continue;
      }
      final value = swingWidth
          ? QuickModeSelectionResolver.swingWidthOf(row)
          : row.thickness;
      if (value == null) {
        continue;
      }
      final key = QuickModeSelectionResolver.dimensionKey(value);
      if (seen.add(key)) {
        out.add(value);
      }
    }
    return out;
  }

  static ProcessPreset? findMatched({
    required List<ProcessPreset> rows,
    required MaterialType? material,
    required int? gear,
    required double? dimension,
    required bool swingWidth,
  }) {
    if (material == null || gear == null || dimension == null) {
      return null;
    }
    for (final row in rows) {
      if (row.materialType != material || row.gear != gear) {
        continue;
      }
      final got = swingWidth
          ? QuickModeSelectionResolver.swingWidthOf(row)
          : row.thickness;
      if (QuickModeSelectionResolver.dimensionKey(got) ==
          QuickModeSelectionResolver.dimensionKey(dimension)) {
        return row;
      }
    }
    return null;
  }

  /// Full re-resolve used on process-type or material change.
  static QuickModeSelection resolve({
    required List<ProcessPreset> rows,
    required ProcessType processType,
    MaterialType? localMaterial,
    int? localGear,
    double? localThickness,
    double? localSwingWidth,
  }) {
    final useSwingWidth = processType.isCleaning;
    final materials = materialsOf(rows);

    MaterialType? material;
    final preferredMaterialStorage = QuickModeSelectionResolver
        .preferCarryThenLocal(
      QuickModeSelectionCarry.materialType,
      localMaterial?.storageValue,
    );
    if (preferredMaterialStorage != null) {
      for (final candidate in materials) {
        if (candidate.storageValue == preferredMaterialStorage) {
          material = candidate;
          break;
        }
      }
    }
    material ??= materials.isEmpty ? null : materials.first;

    final gears = gearsOf(rows, material);
    final preferredGear = QuickModeSelectionResolver.preferCarryThenLocal(
      QuickModeSelectionCarry.gear,
      localGear,
    );
    var gearIndex =
        QuickModeSelectionResolver.indexOfGear(gears, preferredGear);
    if (gearIndex < 0) {
      gearIndex = 0;
    }
    final gear = gears.isEmpty ? null : gears[gearIndex];

    final dimensions = dimensionsOf(
      rows,
      material: material,
      swingWidth: useSwingWidth,
    );
    final preferredDimension = useSwingWidth
        ? QuickModeSelectionResolver.preferCarryThenLocal(
            QuickModeSelectionCarry.swingWidth,
            localSwingWidth,
          )
        : QuickModeSelectionResolver.preferCarryThenLocal(
            QuickModeSelectionCarry.thickness,
            localThickness,
          );
    final dimensionIndex = QuickModeSelectionResolver.resolveDimensionIndex(
      dimensionList: dimensions,
      dataList: rows,
      materialType: material,
      gear: gear,
      preferred: preferredDimension,
      swingWidth: useSwingWidth,
    );
    final dimension = dimensions.isEmpty ? null : dimensions[dimensionIndex];

    QuickModeSelectionCarry.remember(
      material: material?.storageValue,
      gearValue: gear,
      thicknessValue: useSwingWidth ? null : dimension,
      swingWidthValue: useSwingWidth ? dimension : null,
    );

    return QuickModeSelection(
      materials: materials,
      gears: gears,
      dimensions: dimensions,
      material: material,
      gear: gear,
      dimension: dimension,
      useSwingWidth: useSwingWidth,
      matched: findMatched(
        rows: rows,
        material: material,
        gear: gear,
        dimension: dimension,
        swingWidth: useSwingWidth,
      ),
    );
  }

  /// Gear-only change: keep dimension list; may yield no matched row.
  static QuickModeSelection withGear({
    required QuickModeSelection current,
    required List<ProcessPreset> rows,
    required int gear,
  }) {
    QuickModeSelectionCarry.remember(
      material: current.material?.storageValue,
      gearValue: gear,
      thicknessValue: current.thickness,
      swingWidthValue: current.swingWidth,
    );
    return QuickModeSelection(
      materials: current.materials,
      gears: current.gears,
      dimensions: current.dimensions,
      material: current.material,
      gear: gear,
      dimension: current.dimension,
      useSwingWidth: current.useSwingWidth,
      matched: findMatched(
        rows: rows,
        material: current.material,
        gear: gear,
        dimension: current.dimension,
        swingWidth: current.useSwingWidth,
      ),
    );
  }

  /// Dimension-only change.
  static QuickModeSelection withDimension({
    required QuickModeSelection current,
    required List<ProcessPreset> rows,
    required double dimension,
  }) {
    QuickModeSelectionCarry.remember(
      material: current.material?.storageValue,
      gearValue: current.gear,
      thicknessValue: current.useSwingWidth ? null : dimension,
      swingWidthValue: current.useSwingWidth ? dimension : null,
    );
    return QuickModeSelection(
      materials: current.materials,
      gears: current.gears,
      dimensions: current.dimensions,
      material: current.material,
      gear: current.gear,
      dimension: dimension,
      useSwingWidth: current.useSwingWidth,
      matched: findMatched(
        rows: rows,
        material: current.material,
        gear: current.gear,
        dimension: dimension,
        swingWidth: current.useSwingWidth,
      ),
    );
  }
}

/// Route args for Quick → Engineer "More Parameters" handoff.
final class EngineerModeRouteArgs {
  const EngineerModeRouteArgs({
    this.processType,
    this.presetUuid,
  });

  final ProcessType? processType;
  final String? presetUuid;
}
