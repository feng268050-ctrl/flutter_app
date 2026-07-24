import 'dart:collection';

const _unset = Object();

enum ProcessPresetKind {
  quick('quick'),
  engineerPreset('engineer_preset'),
  user('user');

  const ProcessPresetKind(this.storageValue);
  final String storageValue;

  static ProcessPresetKind parse(String value) => values.firstWhere(
        (kind) => kind.storageValue == value,
        orElse: () =>
            throw FormatException('Unknown process preset kind: $value'),
      );
}

enum ProcessType {
  continuousWelding(0, 'Continuous Weld'),
  spotWelding(1, 'Spot welding'),
  weldCleaning(2, 'Weld Path Clean'),
  wideCleaning(3, 'Ultra-wide Clean'),
  handCutting(4, 'Cut'),
  cncCutting(5, 'CNC Cut');

  const ProcessType(this.wireValue, this.label);
  final int wireValue;
  final String label;

  bool get isCleaning =>
      this == ProcessType.weldCleaning || this == ProcessType.wideCleaning;

  static ProcessType fromWireValue(int value) => values.firstWhere(
        (type) => type.wireValue == value,
        orElse: () => throw FormatException('Unknown process type: $value'),
      );
}

enum MaterialType {
  stainlessSteel(1, 'Stainless steel', 'Stainless Steel'),
  carbonSteel(2, 'Carbon steel', 'Carbon Steel'),
  galvanizedSheet(3, 'Galvanized sheet', 'Galvanized Sheet'),
  aluminumAlloy(4, 'Aluminum alloy', 'Aluminum Alloy'),
  brass(5, 'Brass', 'Brass'),
  custom(6, 'Custom', 'Custom');

  const MaterialType(this.storageValue, this.label, this.englishName);
  final int storageValue;
  final String label;

  /// Title-case English label used by lws-ui engineer bootstrap naming.
  final String englishName;

  static MaterialType fromStorageValue(int value) => values.firstWhere(
        (material) => material.storageValue == value,
        orElse: () => throw FormatException('Unknown material type: $value'),
      );
}

final class ProcessParameterSpec {
  const ProcessParameterSpec({
    required this.key,
    required this.column,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String key;
  final String column;
  final String label;
  final String unit;
  final double min;
  final double max;
}

/// Business-unit parameters backed by the named columns in process_presets.
///
/// The current HAL catalog exposes 22 named `process.*` attributes. The Modbus
/// group reserves 23 registers, but no domain field is invented for the spare
/// register.
abstract final class ProcessParameterCatalog {
  static const specs = <ProcessParameterSpec>[
    ProcessParameterSpec(
        key: 'process.laser_power',
        column: 'laser_power',
        label: 'Laser power',
        unit: '%',
        min: 0,
        max: 100),
    ProcessParameterSpec(
        key: 'process.laser_duty_cycle',
        column: 'laser_duty_cycle',
        label: 'Laser duty cycle',
        unit: '%',
        min: 0,
        max: 100),
    ProcessParameterSpec(
        key: 'process.laser_frequency',
        column: 'laser_frequency',
        label: 'Laser frequency',
        unit: 'Hz',
        min: 1,
        max: 5000),
    ProcessParameterSpec(
        key: 'process.piercing_power',
        column: 'piercing_power',
        label: 'Piercing power',
        unit: '%',
        min: 0,
        max: 100),
    ProcessParameterSpec(
        key: 'process.piercing_frequency',
        column: 'piercing_frequency',
        label: 'Piercing frequency',
        unit: 'Hz',
        min: 0,
        max: 2000),
    ProcessParameterSpec(
        key: 'process.piercing_duty_cycle',
        column: 'piercing_duty_cycle',
        label: 'Piercing duty cycle',
        unit: '%',
        min: 0,
        max: 100),
    ProcessParameterSpec(
        key: 'process.swing_frequency',
        column: 'swing_frequency',
        label: 'Swing frequency',
        unit: 'Hz',
        min: 0,
        max: 220),
    ProcessParameterSpec(
        key: 'process.swing_width',
        column: 'swing_width',
        label: 'Swing width',
        unit: 'mm',
        min: 0,
        max: 6),
    ProcessParameterSpec(
        key: 'process.wire_feeding_speed',
        column: 'wire_feeding_speed',
        label: 'Wire feeding speed',
        unit: 'mm/s',
        min: 0,
        max: 50),
    ProcessParameterSpec(
        key: 'process.back_draw_length',
        column: 'back_draw_length',
        label: 'Back draw length',
        unit: 'mm',
        min: 0,
        max: 35),
    ProcessParameterSpec(
        key: 'process.back_draw_speed',
        column: 'back_draw_speed',
        label: 'Back draw speed',
        unit: 'mm/s',
        min: 3,
        max: 100),
    ProcessParameterSpec(
        key: 'process.wire_filling_length',
        column: 'wire_filling_length',
        label: 'Wire filling length',
        unit: 'mm',
        min: 0,
        max: 35),
    ProcessParameterSpec(
        key: 'process.wire_filling_delay',
        column: 'wire_filling_delay',
        label: 'Wire filling delay',
        unit: 'ms',
        min: 0,
        max: 1000),
    ProcessParameterSpec(
        key: 'process.wire_feeding_delay',
        column: 'wire_feeding_delay',
        label: 'Wire feeding delay',
        unit: 'ms',
        min: 0,
        max: 2000),
    ProcessParameterSpec(
        key: 'process.blowing_delay',
        column: 'blowing_delay',
        label: 'Blowing delay',
        unit: 'ms',
        min: 0,
        max: 10000),
    ProcessParameterSpec(
        key: 'process.gas_off_delay',
        column: 'gas_off_delay',
        label: 'Gas off delay',
        unit: 'ms',
        min: 0,
        max: 10000),
    ProcessParameterSpec(
        key: 'process.light_off_delay',
        column: 'light_off_delay',
        label: 'Light off delay',
        unit: 'ms',
        min: 0,
        max: 1000),
    ProcessParameterSpec(
        key: 'process.power_ramp_up_duration',
        column: 'power_ramp_up_duration',
        label: 'Power ramp-up',
        unit: 'ms',
        min: 0,
        max: 1000),
    ProcessParameterSpec(
        key: 'process.power_ramp_down_duration',
        column: 'power_ramp_down_duration',
        label: 'Power ramp-down',
        unit: 'ms',
        min: 0,
        max: 1000),
    ProcessParameterSpec(
        key: 'process.spot_welding_duration',
        column: 'spot_welding_duration',
        label: 'Spot welding duration',
        unit: 'ms',
        min: 0,
        max: 10000),
    ProcessParameterSpec(
        key: 'process.spot_welding_interval',
        column: 'spot_welding_interval',
        label: 'Spot welding interval',
        unit: 'ms',
        min: 0,
        max: 10000),
    ProcessParameterSpec(
        key: 'process.piercing_duration',
        column: 'piercing_duration',
        label: 'Piercing duration',
        unit: 'ms',
        min: 0,
        max: 2000),
  ];

  static final byKey = {for (final spec in specs) spec.key: spec};
  static final byColumn = {for (final spec in specs) spec.column: spec};
}

final class ProcessParameters {
  ProcessParameters(Map<String, num?> values)
      : values = UnmodifiableMapView({
          for (final entry in values.entries)
            if (entry.value != null) entry.key: entry.value!.toDouble(),
        }) {
    final unknown = this
        .values
        .keys
        .where((key) => !ProcessParameterCatalog.byKey.containsKey(key))
        .toList();
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unknown process parameters: $unknown');
    }
  }

  const ProcessParameters.empty() : values = const {};

  final Map<String, double> values;

  Map<String, Object?> toJson() => Map<String, Object?>.from(values);

  static ProcessParameters fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('parameters must be an object');
    }
    final parsed = <String, num?>{};
    for (final entry in value.entries) {
      if (entry.value != null && entry.value is! num) {
        throw FormatException('${entry.key} must be numeric or null');
      }
      parsed[entry.key] = entry.value as num?;
    }
    return ProcessParameters(parsed);
  }
}

final class ProcessPreset {
  const ProcessPreset({
    this.id,
    required this.uuid,
    required this.name,
    required this.kind,
    required this.source,
    required this.isBuiltin,
    required this.processType,
    this.materialType,
    this.materialName,
    this.thickness,
    this.gear,
    required this.parameters,
    this.libraryVersion,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.revision = 1,
  });

  final int? id;
  final String uuid;
  final String name;
  final ProcessPresetKind kind;
  final String source;
  final bool isBuiltin;
  final ProcessType processType;
  final MaterialType? materialType;
  final String? materialName;
  final double? thickness;
  final int? gear;
  final ProcessParameters parameters;
  final String? libraryVersion;
  final int createdAtMs;
  final int updatedAtMs;
  final int revision;

  ProcessPreset copyWith({
    Object? id = _unset,
    String? uuid,
    String? name,
    ProcessPresetKind? kind,
    String? source,
    bool? isBuiltin,
    ProcessType? processType,
    Object? materialType = _unset,
    Object? materialName = _unset,
    Object? thickness = _unset,
    Object? gear = _unset,
    ProcessParameters? parameters,
    Object? libraryVersion = _unset,
    int? createdAtMs,
    int? updatedAtMs,
    int? revision,
  }) {
    return ProcessPreset(
      id: identical(id, _unset) ? this.id : id as int?,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      processType: processType ?? this.processType,
      materialType: identical(materialType, _unset)
          ? this.materialType
          : materialType as MaterialType?,
      materialName: identical(materialName, _unset)
          ? this.materialName
          : materialName as String?,
      thickness:
          identical(thickness, _unset) ? this.thickness : thickness as double?,
      gear: identical(gear, _unset) ? this.gear : gear as int?,
      parameters: parameters ?? this.parameters,
      libraryVersion: identical(libraryVersion, _unset)
          ? this.libraryVersion
          : libraryVersion as String?,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      revision: revision ?? this.revision,
    );
  }
}

final class ProcessLibraryMeta {
  const ProcessLibraryMeta({
    required this.source,
    required this.libraryVersion,
    required this.schemaVersion,
    required this.contentSha256,
    required this.installedAtMs,
    required this.rowCount,
  });

  final String source;
  final String libraryVersion;
  final int schemaVersion;
  final String contentSha256;
  final int installedAtMs;
  final int rowCount;
}

final class ProcessLibraryValidationException implements Exception {
  const ProcessLibraryValidationException(this.errors);
  final List<String> errors;

  @override
  String toString() => 'Invalid process parameters: ${errors.join('; ')}';
}

abstract final class ProcessParameterValidator {
  static void validate(ProcessPreset preset) {
    final errors = <String>[];
    if (preset.name.trim().isEmpty) {
      errors.add('name is required');
    }
    if (preset.uuid.trim().isEmpty) {
      errors.add('uuid is required');
    }
    if (preset.parameters.values.isEmpty) {
      errors.add('at least one process parameter is required');
    }
    if (preset.kind == ProcessPresetKind.quick) {
      if (preset.materialType == null) {
        errors.add('quick preset material is required');
      }
      if (preset.processType.isCleaning) {
        if (preset.parameters.values['process.swing_width'] == null) {
          errors.add('quick cleaning preset swing width is required');
        }
      } else if (preset.thickness == null) {
        errors.add('quick preset thickness is required');
      }
      if (preset.gear == null) {
        errors.add('quick preset gear is required');
      }
    }
    if (preset.materialType == MaterialType.custom &&
        (preset.materialName == null || preset.materialName!.trim().isEmpty)) {
      errors.add('custom material name is required');
    }
    for (final entry in preset.parameters.values.entries) {
      final spec = ProcessParameterCatalog.byKey[entry.key]!;
      var min = spec.min;
      var max = spec.max;
      if (entry.key == 'process.swing_frequency' &&
          preset.processType.isCleaning) {
        min = 20;
        max = 220;
      }
      if (entry.key == 'process.swing_width' &&
          preset.processType == ProcessType.wideCleaning) {
        min = 0;
        max = 30;
      }
      if (entry.value < min || entry.value > max) {
        errors.add('${spec.label} must be $min..$max ${spec.unit}');
      }
    }
    if (preset.gear != null && preset.gear! < 0) {
      errors.add('gear must not be negative');
    }
    if (preset.thickness != null && preset.thickness! < 0) {
      errors.add('thickness must not be negative');
    }
    if (errors.isNotEmpty) {
      throw ProcessLibraryValidationException(errors);
    }
  }
}
