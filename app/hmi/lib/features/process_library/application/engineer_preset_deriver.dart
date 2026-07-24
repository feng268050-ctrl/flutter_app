import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

/// Derives built-in [ProcessPresetKind.engineerPreset] rows from quick presets.
///
/// Mirrors lws-ui `EngineerCommonParamsBootstrap` median selection, but rebuilds
/// derived presets on every successful import (explicit JSON engineer rows win).
abstract final class EngineerPresetDeriver {
  static const maxNameLength = 32;

  /// Returns [source] plus any missing derived engineer presets.
  ///
  /// Explicit `engineer_preset` rows in [source] are kept. For each
  /// process-type × non-custom material that has quick rows but no explicit
  /// engineer preset, one median quick row is cloned as `engineer_preset`.
  static List<ProcessPreset> withDerivedEngineerPresets(
    List<ProcessPreset> source, {
    required String libraryVersion,
    int? nowMs,
  }) {
    final timestamp = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final quick = source
        .where((preset) => preset.kind == ProcessPresetKind.quick)
        .toList(growable: false);
    if (quick.isEmpty) {
      return List<ProcessPreset>.from(source);
    }

    final existingEngineerKeys = <String>{};
    for (final preset in source) {
      if (preset.kind != ProcessPresetKind.engineerPreset) {
        continue;
      }
      final material = preset.materialType;
      if (material == null || material == MaterialType.custom) {
        continue;
      }
      existingEngineerKeys.add(_key(preset.processType, material));
    }

    final derived = <ProcessPreset>[];
    final processTypes = quick.map((preset) => preset.processType).toSet().toList()
      ..sort((a, b) => a.wireValue.compareTo(b.wireValue));
    for (final processType in processTypes) {
      final materials = _distinctNonCustomMaterials(quick, processType);
      for (final material in materials) {
        if (existingEngineerKeys.contains(_key(processType, material))) {
          continue;
        }
        final picked = pickMedianQuickPreset(
          quick,
          processType: processType,
          materialType: material,
        );
        if (picked == null) {
          continue;
        }
        derived.add(
          cloneAsEngineerPreset(
            picked,
            libraryVersion: libraryVersion,
            nowMs: timestamp,
          ),
        );
      }
    }
    if (derived.isEmpty) {
      return List<ProcessPreset>.from(source);
    }
    return [...source, ...derived];
  }

  static ProcessPreset? pickMedianQuickPreset(
    List<ProcessPreset> quickRows, {
    required ProcessType processType,
    MaterialType? materialType,
  }) {
    final typeRows = quickRows
        .where(
          (row) =>
              row.kind == ProcessPresetKind.quick &&
              row.processType == processType &&
              (materialType == null || row.materialType == materialType),
        )
        .toList(growable: false);
    if (typeRows.isEmpty) {
      return null;
    }
    final gears = typeRows
        .map((row) => row.gear)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    if (gears.isEmpty) {
      return typeRows.first;
    }
    final medianGear = gears[_medianIndex(gears.length)];
    final gearRows =
        typeRows.where((row) => row.gear == medianGear).toList(growable: false);
    if (gearRows.isEmpty) {
      return typeRows.first;
    }
    if (processType.isCleaning) {
      final widths = gearRows
          .map((row) => _dimensionKey(
                row.parameters.values['process.swing_width'],
              ))
          .toSet()
          .toList()
        ..sort();
      final medianWidth = widths[_medianIndex(widths.length)];
      for (final row in gearRows) {
        if (_dimensionKey(row.parameters.values['process.swing_width']) ==
            medianWidth) {
          return row;
        }
      }
    } else {
      final thicknesses = gearRows
          .map((row) => _dimensionKey(row.thickness))
          .toSet()
          .toList()
        ..sort();
      final medianThickness = thicknesses[_medianIndex(thicknesses.length)];
      for (final row in gearRows) {
        if (_dimensionKey(row.thickness) == medianThickness) {
          return row;
        }
      }
    }
    return gearRows.first;
  }

  static ProcessPreset cloneAsEngineerPreset(
    ProcessPreset source, {
    required String libraryVersion,
    int? nowMs,
    bool useMmUnit = true,
  }) {
    final timestamp = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final name = bootstrapName(source, useMmUnit: useMmUnit);
    final material = source.materialType;
    final uuid = synthesizeUuid(
      libraryVersion: libraryVersion,
      processType: source.processType,
      materialType: material,
    );
    return source.copyWith(
      id: null,
      uuid: uuid,
      name: name,
      kind: ProcessPresetKind.engineerPreset,
      isBuiltin: true,
      libraryVersion: libraryVersion,
      createdAtMs: timestamp,
      updatedAtMs: timestamp,
      revision: 1,
    );
  }

  static String bootstrapName(
    ProcessPreset source, {
    bool useMmUnit = true,
  }) {
    final materialLabel = _englishMaterialName(source);
    if (materialLabel.isEmpty) {
      return '';
    }
    final dimension = source.processType.isCleaning
        ? _formatDimension(
            source.parameters.values['process.swing_width'],
            useMmUnit: useMmUnit,
          )
        : _formatDimension(source.thickness, useMmUnit: useMmUnit);
    if (dimension == null || dimension.isEmpty) {
      return _truncate(materialLabel);
    }
    final unit = useMmUnit ? 'mm' : 'in';
    return _truncate('$materialLabel-$dimension$unit');
  }

  static String synthesizeUuid({
    required String libraryVersion,
    required ProcessType processType,
    MaterialType? materialType,
  }) {
    final identity = jsonEncode([
      libraryVersion,
      'engineer_preset',
      'derived',
      processType.wireValue,
      materialType?.storageValue,
    ]);
    final digest = sha256.convert(utf8.encode(identity)).toString();
    return '${digest.substring(0, 8)}-'
        '${digest.substring(8, 12)}-'
        '${digest.substring(12, 16)}-'
        '${digest.substring(16, 20)}-'
        '${digest.substring(20, 32)}';
  }

  static List<MaterialType> _distinctNonCustomMaterials(
    List<ProcessPreset> quickRows,
    ProcessType processType,
  ) {
    final materials = quickRows
        .where(
          (row) =>
              row.processType == processType &&
              row.materialType != null &&
              row.materialType != MaterialType.custom,
        )
        .map((row) => row.materialType!)
        .toSet()
        .toList()
      ..sort((a, b) => a.storageValue.compareTo(b.storageValue));
    return materials;
  }

  static String _key(ProcessType processType, MaterialType material) =>
      '${processType.wireValue}|${material.storageValue}';

  static int _medianIndex(int size) {
    if (size <= 0) {
      return 0;
    }
    return (size - 1) ~/ 2;
  }

  static double _dimensionKey(double? value) => value ?? 0;

  static String _englishMaterialName(ProcessPreset source) {
    final material = source.materialType;
    if (material == null) {
      final fallback = source.materialName?.trim() ?? '';
      return fallback;
    }
    if (material == MaterialType.custom) {
      final custom = source.materialName?.trim();
      return (custom == null || custom.isEmpty) ? material.englishName : custom;
    }
    return material.englishName;
  }

  static String? _formatDimension(
    double? valueMm, {
    required bool useMmUnit,
  }) {
    if (valueMm == null) {
      return null;
    }
    if (useMmUnit) {
      return _asDecimal(valueMm);
    }
    // Inch path kept for parity with lws-ui; HMI bootstrap always uses mm.
    return _asDecimal(valueMm / 25.4);
  }

  /// Matches lws-ui `ProcessParameterDisplayFormat.asDecimal` (1dp, strip zeros).
  static String _asDecimal(double value) {
    final scaled = (value * 10).roundToDouble() / 10.0;
    if (scaled == scaled.truncateToDouble()) {
      return scaled.toInt().toString();
    }
    return scaled.toStringAsFixed(1);
  }

  static String _truncate(String value) {
    if (value.length <= maxNameLength) {
      return value;
    }
    return value.substring(0, maxNameLength);
  }
}
