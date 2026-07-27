import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:lws_hmi/features/process_library/application/engineer_preset_deriver.dart';
import 'package:lws_hmi/features/process_library/application/process_library_import_audit.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';

export 'package:lws_hmi/features/process_library/application/process_library_import_audit.dart'
    show
        ProcessLibraryImportAudit,
        ProcessLibraryImportResult,
        ProcessLibraryImportStatus;

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
    final audit = await _importFromManifest(
      manifestText: await bundle.loadString(manifestAsset),
      packagePath: null,
      defaultSource: 'bundled',
      loadLibraryBytes: (relative) => _loadAssetBytes(relative),
    );
    return audit.toResult();
  }

  Future<String> resolveDeviceModel() => _resolveDeviceModel();

  /// Import a versioned package directory (`manifest.json` + library JSON).
  ///
  /// [defaultSource] is used when the selected library entry omits `source`
  /// (typical values: `usb`, `ota`).
  Future<ProcessLibraryImportAudit> importPackageFromDirectory(
    Directory root, {
    String defaultSource = 'usb',
  }) async {
    final manifestFile = File('${root.path}/manifest.json');
    if (!await manifestFile.exists()) {
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: root.path,
        source: defaultSource,
        errors: const ['manifest.json not found'],
        skippedReason: 'missing_manifest',
      );
    }
    try {
      return await _importFromManifest(
        manifestText: await manifestFile.readAsString(),
        packagePath: root.path,
        defaultSource: defaultSource,
        loadLibraryBytes: (relative) async {
          final cleaned = relative
              .replaceFirst(RegExp(r'^assets/process-library/'), '')
              .replaceFirst(RegExp(r'^/+'), '');
          final file = File('${root.path}/$cleaned');
          if (!await file.exists()) {
            throw FormatException('Library file missing: $cleaned');
          }
          return file.readAsBytes();
        },
      );
    } catch (error) {
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: root.path,
        source: defaultSource,
        errors: ['$error'],
        skippedReason: 'validation_failed',
      );
    }
  }

  Future<ProcessLibraryImportAudit> _importFromManifest({
    required String manifestText,
    required String? packagePath,
    required String defaultSource,
    required Future<Uint8List> Function(String relative) loadLibraryBytes,
  }) async {
    final resolvedModel = await _resolveDeviceModel();
    final preservedUserCount = (await repository.list())
        .where((preset) => preset.kind == ProcessPresetKind.user)
        .length;

    final manifest = _object(jsonDecode(manifestText), 'manifest');
    final schemaVersion =
        _integer(manifest['schema_version'], 'schema_version');
    if (schemaVersion != 1) {
      throw FormatException(
          'Unsupported process manifest schema: $schemaVersion');
    }

    final selected = _selectLibrary(manifest, resolvedModel);
    if (selected == null) {
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.noCompatibleLibrary,
        packagePath: packagePath,
        modelMatched: false,
        preservedUserCount: preservedUserCount,
        skippedReason: 'no_compatible_library',
        errors: [
          'No library matches device model "$resolvedModel"',
        ],
      );
    }

    final source = (selected['source']?.toString().trim().isNotEmpty ?? false)
        ? selected['source'].toString().trim()
        : defaultSource;
    final version =
        _requiredString(selected['library_version'], 'library_version');
    final expectedHash =
        _requiredString(selected['content_sha256'], 'content_sha256')
            .toLowerCase();
    final asset = _requiredString(selected['asset'], 'asset');
    final installed = await repository.metaFor(source);
    final models = _list(selected['supported_models'], 'supported_models')
        .map((value) => value.toString().trim().toLowerCase())
        .toSet();
    final modelMatched =
        models.contains(resolvedModel) || models.contains('*');

    final bytes = await loadLibraryBytes(asset);
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
    final rowErrors = <String>[];
    for (var index = 0; index < rows.length; index++) {
      try {
        final preset = _preset(
          _object(rows[index], 'presets[$index]'),
          source: source,
          version: version,
        );
        if (!uuids.add(preset.uuid)) {
          throw FormatException(
              'Duplicate process preset uuid: ${preset.uuid}');
        }
        if (preset.kind == ProcessPresetKind.quick) {
          final swingWidth = preset.parameters.values['process.swing_width'];
          final lookup = '${preset.processType.wireValue}|'
              '${preset.materialType?.storageValue}|${preset.thickness}|'
              '$swingWidth|${preset.gear}';
          if (!quickLookups.add(lookup)) {
            throw FormatException('Duplicate quick process lookup: $lookup');
          }
        }
        ProcessParameterValidator.validate(preset);
        presets.add(preset);
      } catch (error) {
        rowErrors.add('presets[$index]: $error');
      }
    }
    if (rowErrors.isNotEmpty) {
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: packagePath,
        source: source,
        fromVersion: installed?.libraryVersion,
        toVersion: version,
        contentSha256: actualHash,
        modelMatched: modelMatched,
        preservedUserCount: preservedUserCount,
        skippedReason: 'row_validation_failed',
        errors: rowErrors,
        meta: installed,
      );
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
        return ProcessLibraryImportAudit(
          status: ProcessLibraryImportStatus.current,
          packagePath: packagePath,
          source: source,
          fromVersion: installed.libraryVersion,
          toVersion: version,
          contentSha256: actualHash,
          rowCount: installed.rowCount,
          modelMatched: modelMatched,
          preservedUserCount: preservedUserCount,
          skippedReason: 'already_installed',
          meta: installed,
        );
      }
    } else if (installed != null &&
        _compareVersions(version, installed.libraryVersion) < 0) {
      // Bundled asset older than installed → keep current quietly.
      // External packages → explicit reject for the audit UI.
      if (packagePath == null) {
        return ProcessLibraryImportAudit(
          status: ProcessLibraryImportStatus.current,
          packagePath: packagePath,
          source: source,
          fromVersion: installed.libraryVersion,
          toVersion: version,
          contentSha256: actualHash,
          modelMatched: modelMatched,
          preservedUserCount: preservedUserCount,
          skippedReason: 'older_than_installed',
          meta: installed,
        );
      }
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: packagePath,
        source: source,
        fromVersion: installed.libraryVersion,
        toVersion: version,
        contentSha256: actualHash,
        modelMatched: modelMatched,
        preservedUserCount: preservedUserCount,
        skippedReason: 'older_version',
        errors: [
          'Package version $version is older than installed '
              '${installed.libraryVersion}',
        ],
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
    return ProcessLibraryImportAudit(
      status: ProcessLibraryImportStatus.imported,
      packagePath: packagePath,
      source: source,
      fromVersion: installed?.libraryVersion,
      toVersion: version,
      contentSha256: actualHash,
      rowCount: presetsWithEngineer.length,
      modelMatched: modelMatched,
      preservedUserCount: preservedUserCount,
      meta: meta,
    );
  }

  Future<String> _resolveDeviceModel() async {
    final loadedModel = await deviceModelLoader?.call();
    return (loadedModel == null || loadedModel.trim().isEmpty
            ? deviceModel
            : loadedModel)
        .trim()
        .toLowerCase();
  }

  /// Peek package metadata without writing the database.
  static ProcessLibraryPackagePeek? peekManifest(
    String manifestText, {
    required String deviceModel,
  }) {
    try {
      final resolvedModel = deviceModel.trim().toLowerCase();
      final manifest = _object(jsonDecode(manifestText), 'manifest');
      final schemaVersion =
          _integer(manifest['schema_version'], 'schema_version');
      if (schemaVersion != 1) {
        return null;
      }
      final selected = _selectLibrary(manifest, resolvedModel);
      if (selected == null) {
        final any = _list(manifest['libraries'], 'libraries')
            .map((value) => _object(value, 'library'))
            .toList();
        if (any.isEmpty) {
          return null;
        }
        any.sort((a, b) => _compareVersions(
              b['library_version'].toString(),
              a['library_version'].toString(),
            ));
        final first = any.first;
        return ProcessLibraryPackagePeek(
          libraryVersion:
              _requiredString(first['library_version'], 'library_version'),
          source: first['source']?.toString() ?? 'usb',
          supportedModels: _list(first['supported_models'], 'supported_models')
              .map((value) => value.toString())
              .toList(growable: false),
          modelMatched: false,
          asset: _requiredString(first['asset'], 'asset'),
          contentSha256:
              _requiredString(first['content_sha256'], 'content_sha256'),
          rowCount: _integer(first['row_count'], 'row_count'),
        );
      }
      return ProcessLibraryPackagePeek(
        libraryVersion:
            _requiredString(selected['library_version'], 'library_version'),
        source: selected['source']?.toString() ?? 'usb',
        supportedModels:
            _list(selected['supported_models'], 'supported_models')
                .map((value) => value.toString())
                .toList(growable: false),
        modelMatched: true,
        asset: _requiredString(selected['asset'], 'asset'),
        contentSha256:
            _requiredString(selected['content_sha256'], 'content_sha256'),
        rowCount: _integer(selected['row_count'], 'row_count'),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _selectLibrary(
    Map<String, dynamic> manifest,
    String resolvedModel,
  ) {
    final libraries = _list(manifest['libraries'], 'libraries')
        .map((value) => _object(value, 'library'))
        .where((library) {
      final models = _list(library['supported_models'], 'supported_models')
          .map((value) => value.toString().trim().toLowerCase())
          .toSet();
      return models.contains(resolvedModel) || models.contains('*');
    }).toList();
    if (libraries.isEmpty) {
      return null;
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
    return libraries.first;
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

  Future<Uint8List> _loadAssetBytes(String asset) async {
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

/// Lightweight metadata from a package manifest (no DB writes).
final class ProcessLibraryPackagePeek {
  const ProcessLibraryPackagePeek({
    required this.libraryVersion,
    required this.source,
    required this.supportedModels,
    required this.modelMatched,
    required this.asset,
    required this.contentSha256,
    required this.rowCount,
  });

  final String libraryVersion;
  final String source;
  final List<String> supportedModels;
  final bool modelMatched;
  final String asset;
  final String contentSha256;
  final int rowCount;
}
