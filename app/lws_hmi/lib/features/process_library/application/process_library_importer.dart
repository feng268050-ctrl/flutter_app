import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/features/process_library/application/engineer_preset_deriver.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';

enum ProcessLibraryImportStatus {
  imported,
  current,
  noCompatibleLibrary,
}

final class ProcessLibraryImportResult {
  const ProcessLibraryImportResult(this.status, {this.meta});

  final ProcessLibraryImportStatus status;
  final ProcessLibraryMeta? meta;
}

final class ProcessLibraryImporter {
  ProcessLibraryImporter({
    required this.repository,
    this.deviceModel = '',
    this.deviceModelLoader,
    AssetBundle? bundle,
    this.manifestAsset = 'assets/process-library/manifest.json',
  }) : bundle = bundle ?? rootBundle;

  final ProcessLibraryRepository repository;
  final String deviceModel;
  final Future<String> Function()? deviceModelLoader;
  final AssetBundle bundle;
  final String manifestAsset;

  Future<ProcessLibraryImportResult> importBundled() async {
    final loadedModel = await deviceModelLoader?.call();
    final resolvedModel = (loadedModel == null || loadedModel.trim().isEmpty
            ? deviceModel
            : loadedModel)
        .trim()
        .toLowerCase();
    final manifestText = await bundle.loadString(manifestAsset);
    final manifest = _object(jsonDecode(manifestText), 'manifest');
    final schemaVersion =
        _integer(manifest['schema_version'], 'schema_version');
    if (schemaVersion != 1) {
      throw FormatException(
          'Unsupported process manifest schema: $schemaVersion');
    }
    final libraries = _list(manifest['libraries'], 'libraries')
        .map((value) => _object(value, 'library'))
        .where((library) {
      final models = _list(library['supported_models'], 'supported_models')
          .map((value) => value.toString().trim().toLowerCase())
          .toSet();
      return models.contains(resolvedModel) || models.contains('*');
    }).toList();
    if (libraries.isEmpty) {
      return const ProcessLibraryImportResult(
        ProcessLibraryImportStatus.noCompatibleLibrary,
      );
    }
    libraries.sort((a, b) {
      final aSpecific = _list(a['supported_models'], 'supported_models')
          .map((value) => value.toString().trim().toLowerCase())
          .contains(resolvedModel);
      final bSpecific = _list(b['supported_models'], 'supported_models')
          .map((value) => value.toString().trim().toLowerCase())
          .contains(resolvedModel);
      if (aSpecific != bSpecific) {
        return aSpecific ? -1 : 1;
      }
      return _compareVersions(
        b['library_version'].toString(),
        a['library_version'].toString(),
      );
    });
    final selected = libraries.first;
    final source = selected['source']?.toString() ?? 'bundled';
    final version =
        _requiredString(selected['library_version'], 'library_version');
    final expectedHash =
        _requiredString(selected['content_sha256'], 'content_sha256')
            .toLowerCase();
    final installed = await repository.metaFor(source);
    final asset = _requiredString(selected['asset'], 'asset');
    final bytes = await _loadBytes(asset);
    final actualHash = sha256.convert(bytes).toString();
    if (actualHash != expectedHash) {
      throw FormatException(
        'Process library hash mismatch for $asset: '
        'expected $expectedHash, got $actualHash',
      );
    }
    final document = _object(
      jsonDecode(utf8.decode(bytes)),
      'process library',
    );
    if (_integer(document['schema_version'], 'schema_version') !=
        schemaVersion) {
      throw const FormatException('Manifest/library schema mismatch');
    }
    if (document['library_version']?.toString() != version) {
      throw const FormatException('Manifest/library version mismatch');
    }
    final rows = _list(document['presets'], 'presets');
    final presets = <ProcessPreset>[];
    final uuids = <String>{};
    final quickLookups = <String>{};
    for (var index = 0; index < rows.length; index++) {
      final preset = _preset(
        _object(rows[index], 'presets[$index]'),
        source: source,
        version: version,
      );
      if (!uuids.add(preset.uuid)) {
        throw FormatException('Duplicate process preset uuid: ${preset.uuid}');
      }
      if (preset.kind == ProcessPresetKind.quick) {
        final swingWidth =
            preset.parameters.values['process.swing_width'];
        final lookup = '${preset.processType.wireValue}|'
            '${preset.materialType?.storageValue}|${preset.thickness}|'
            '$swingWidth|${preset.gear}';
        if (!quickLookups.add(lookup)) {
          throw FormatException('Duplicate quick process lookup: $lookup');
        }
      }
      ProcessParameterValidator.validate(preset);
      presets.add(preset);
    }
    final declaredCount = _integer(selected['row_count'], 'row_count');
    if (declaredCount != presets.length) {
      throw FormatException(
        'Process library row count mismatch: '
        'expected $declaredCount, got ${presets.length}',
      );
    }
    final installedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final presetsWithEngineer = EngineerPresetDeriver.withDerivedEngineerPresets(
      presets,
      libraryVersion: version,
      nowMs: installedAtMs,
    );
    for (final preset in presetsWithEngineer) {
      ProcessParameterValidator.validate(preset);
    }

    if (installed != null &&
        installed.libraryVersion == version &&
        installed.contentSha256 == expectedHash) {
      final existing = (await repository.list())
          .where((preset) => preset.source == source)
          .toList(growable: false);
      if (!_engineerDerivationMissing(existing, presetsWithEngineer)) {
        return ProcessLibraryImportResult(
          ProcessLibraryImportStatus.current,
          meta: installed,
        );
      }
    } else if (installed != null &&
        _compareVersions(version, installed.libraryVersion) < 0) {
      return ProcessLibraryImportResult(
        ProcessLibraryImportStatus.current,
        meta: installed,
      );
    }

    final meta = ProcessLibraryMeta(
      source: source,
      libraryVersion: version,
      schemaVersion: schemaVersion,
      contentSha256: actualHash,
      installedAtMs: installedAtMs,
      rowCount: presetsWithEngineer.length,
    );
    await repository.replaceBuiltins(
      source: source,
      meta: meta,
      presets: presetsWithEngineer,
    );
    return ProcessLibraryImportResult(
      ProcessLibraryImportStatus.imported,
      meta: meta,
    );
  }

  /// True when the live DB is missing derived/explicit engineer presets that
  /// the current asset+deriver would install.
  static bool _engineerDerivationMissing(
    List<ProcessPreset> existing,
    List<ProcessPreset> desired,
  ) {
    String key(ProcessPreset preset) =>
        '${preset.kind.storageValue}|${preset.processType.wireValue}|'
        '${preset.materialType?.storageValue}|${preset.uuid}';
    final existingKeys = existing.map(key).toSet();
    for (final preset in desired) {
      if (preset.kind != ProcessPresetKind.engineerPreset) {
        continue;
      }
      if (!existingKeys.contains(key(preset))) {
        return true;
      }
    }
    return false;
  }

  Future<Uint8List> _loadBytes(String asset) async {
    final data = await bundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static ProcessPreset _preset(
    Map<String, dynamic> value, {
    required String source,
    required String version,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final kind = ProcessPresetKind.parse(value['kind'].toString());
    if (kind == ProcessPresetKind.user) {
      throw const FormatException(
          'Bundled library cannot contain user presets');
    }
    return ProcessPreset(
      uuid: _requiredString(value['uuid'], 'uuid'),
      name: _requiredString(value['name'], 'name'),
      kind: kind,
      source: source,
      isBuiltin: true,
      processType: ProcessType.fromWireValue(
        _integer(value['process_type'], 'process_type'),
      ),
      materialType: value['material_type'] == null
          ? null
          : MaterialType.fromStorageValue(
              _integer(value['material_type'], 'material_type'),
            ),
      materialName: value['material_name']?.toString(),
      thickness: (value['thickness'] as num?)?.toDouble(),
      gear: value['gear'] == null ? null : _integer(value['gear'], 'gear'),
      parameters: ProcessParameters.fromJson(value['parameters']),
      libraryVersion: version,
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$label must be an object');
    }
    return value;
  }

  static List<dynamic> _list(Object? value, String label) {
    if (value is! List<dynamic>) {
      throw FormatException('$label must be an array');
    }
    return value;
  }

  static int _integer(Object? value, String label) {
    if (value is! num || value.toInt() != value) {
      throw FormatException('$label must be an integer');
    }
    return value.toInt();
  }

  static String _requiredString(Object? value, String label) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$label must be a non-empty string');
    }
    return value.trim();
  }

  static int _compareVersions(String left, String right) {
    List<int> parts(String value) {
      if (!RegExp(r'^\d+(\.\d+){0,2}([-+][0-9A-Za-z.-]+)?$').hasMatch(value)) {
        throw FormatException('Invalid process library version: $value');
      }
      return value
          .split(RegExp(r'[-+]'))
          .first
          .split('.')
          .map(int.parse)
          .toList();
    }

    final a = parts(left);
    final b = parts(right);
    for (var i = 0; i < 3; i++) {
      final comparison =
          (i < a.length ? a[i] : 0).compareTo(i < b.length ? b[i] : 0);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }
}
