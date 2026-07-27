import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_library_package_scanner.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';

final class ProcessLibraryController extends ChangeNotifier {
  ProcessLibraryController({
    required this.repository,
    required this.importer,
    required this.applier,
    ProcessLibraryPackageScanner? packageScanner,
  }) : packageScanner = packageScanner ??
            ProcessLibraryPackageScanner(
              deviceModel: importer.deviceModel,
            );

  final ProcessLibraryRepository repository;
  final ProcessLibraryImporter importer;
  final ProcessParameterApplier applier;
  final ProcessLibraryPackageScanner packageScanner;

  List<ProcessPreset> _presets = const [];
  Object? _lastError;
  bool _loading = false;
  bool _initialized = false;
  bool _closed = false;
  bool _applying = false;
  bool _importingExternal = false;

  List<ProcessPreset> get presets => List.unmodifiable(_presets);
  Object? get lastError => _lastError;
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get applying => _applying;
  bool get importingExternal => _importingExternal;

  Future<void> initialize() async {
    if (_closed || _loading || (_initialized && _lastError == null)) {
      return;
    }
    _loading = true;
    _lastError = null;
    _notify();
    try {
      await repository.open();
      try {
        await importer.importBundled();
      } catch (error) {
        // Keep the last successfully installed library available.
        _lastError = error;
        debugPrint('process-library bundled import failed: $error');
      }
      _presets = await repository.list();
      _initialized = true;
    } catch (error) {
      _lastError = error;
      debugPrint('process-library initialization failed: $error');
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<List<ProcessLibraryPackageCandidate>> scanImportCandidates() async {
    final model = await importer.resolveDeviceModel();
    final scanner = ProcessLibraryPackageScanner(
      deviceModel: model,
      extraRoots: packageScanner.extraRoots,
      includeDefaultRoots: packageScanner.includeDefaultRoots,
    );
    return scanner.scan();
  }

  Future<ProcessLibraryImportAudit> importExternal(
    ProcessLibraryPackageCandidate candidate,
  ) async {
    if (_importingExternal) {
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: candidate.directoryPath,
        source: candidate.defaultSource,
        skippedReason: 'busy',
        errors: const ['Another import is already in progress'],
      );
    }
    _importingExternal = true;
    _lastError = null;
    _notify();
    try {
      final audit = await importer.importPackageFromDirectory(
        candidate.directory,
        defaultSource: candidate.defaultSource,
      );
      if (audit.status == ProcessLibraryImportStatus.imported ||
          audit.status == ProcessLibraryImportStatus.current) {
        await _reload();
      } else if (audit.errors.isNotEmpty) {
        _lastError = audit.errors.join('\n');
      }
      return audit;
    } catch (error) {
      _lastError = error;
      return ProcessLibraryImportAudit(
        status: ProcessLibraryImportStatus.rejected,
        packagePath: candidate.directoryPath,
        source: candidate.defaultSource,
        skippedReason: 'exception',
        errors: ['$error'],
      );
    } finally {
      _importingExternal = false;
      _notify();
    }
  }

  Iterable<ProcessPreset> quickPresets({ProcessType? processType}) =>
      _presets.where((preset) =>
          preset.kind == ProcessPresetKind.quick &&
          (processType == null || preset.processType == processType));

  Iterable<ProcessPreset> engineerPresets({ProcessType? processType}) =>
      _presets.where((preset) =>
          preset.kind != ProcessPresetKind.quick &&
          (processType == null || preset.processType == processType));

  Future<ProcessPreset> saveUser(ProcessPreset preset) async {
    final saved = await repository.saveUser(preset);
    await _reload();
    return saved;
  }

  Future<ProcessPreset> copyAsUser(ProcessPreset source, {String? name}) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return saveUser(
      ProcessPreset(
        uuid: _newUuid(),
        name: name ?? '${source.name} Copy',
        kind: ProcessPresetKind.user,
        source: 'user',
        isBuiltin: false,
        processType: source.processType,
        materialType: source.materialType,
        materialName: source.materialName,
        thickness: source.thickness,
        gear: source.gear,
        parameters: source.parameters,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
  }

  /// Engineer “Save as Favorite”: upsert user row by processType + name (lws-ui).
  Future<ProcessPreset> saveAsFavorite(
    ProcessPreset source, {
    required String name,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Favorite name cannot be empty');
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    ProcessPreset? existing;
    for (final preset in _presets) {
      if (!preset.isBuiltin &&
          preset.kind == ProcessPresetKind.user &&
          preset.processType == source.processType &&
          preset.name == trimmed) {
        existing = preset;
        break;
      }
    }
    if (existing != null) {
      return saveUser(
        existing.copyWith(
          name: trimmed,
          materialType: source.materialType,
          materialName: source.materialName,
          thickness: source.thickness,
          gear: source.gear,
          parameters: source.parameters,
          updatedAtMs: now,
        ),
      );
    }
    return copyAsUser(source, name: trimmed);
  }

  Future<void> deleteUser(ProcessPreset preset) async {
    if (preset.kind != ProcessPresetKind.user || preset.isBuiltin) {
      throw StateError('Built-in process presets are read-only');
    }
    await repository.deleteUser(preset.uuid);
    await _reload();
  }

  Future<ProcessApplyResult> apply(ProcessPreset preset) async {
    if (_applying) {
      return const ProcessApplyResult.failure(ProcessApplyFailure.busy);
    }
    _applying = true;
    _notify();
    try {
      return await applier.apply(preset);
    } finally {
      _applying = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    _presets = await repository.list();
    _notify();
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final text = bytes.map(hex).join();
    return '${text.substring(0, 8)}-${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }

  Future<void> close() {
    _closed = true;
    return repository.close();
  }

  void _notify() {
    if (!_closed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}
