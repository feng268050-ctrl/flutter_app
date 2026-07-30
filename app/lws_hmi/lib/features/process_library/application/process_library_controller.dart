import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/application/process_library_importer.dart';
import 'package:lws_hmi/features/process_library/application/process_parameter_applier.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';
import 'package:lws_hmi/platform/cloud/device_remote_snapshot_modbus_mapper.dart';
import 'package:lws_hmi/platform/cloud/process_parameters_snapshot_store.dart';

final class ProcessLibraryController extends ChangeNotifier {
  ProcessLibraryController({
    required this.repository,
    required this.importer,
    required this.applier,
  });

  final ProcessLibraryRepository repository;
  final ProcessLibraryImporter importer;
  final ProcessParameterApplier applier;

  List<ProcessPreset> _presets = const [];
  Object? _lastError;
  bool _loading = false;
  bool _initialized = false;
  bool _closed = false;
  bool _applying = false;

  List<ProcessPreset> get presets => List.unmodifiable(_presets);
  Object? get lastError => _lastError;
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get applying => _applying;

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
      final result = await applier.apply(preset);
      if (result.isSuccess) {
        ProcessParametersSnapshotStore.instance.updateFromPreset(
          preset,
          DeviceRemoteSnapshotModbusMapper.processParametersFromGroup(
            Map<String, Object?>.from(preset.parameters.values),
          ),
        );
      }
      return result;
    } finally {
      _applying = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    _presets = await repository.list();
    _notify();
  }

  /// Refresh in-memory list after external repository writes (e.g. cloud push).
  Future<void> reloadPresets() => _reload();

  /// Host `make upgrade-process-library`: force-import package and refresh list.
  Future<ProcessLibraryImportAudit> importPackageForced(Directory root) async {
    final audit = await importer.importPackageFromDirectory(
      root,
      force: true,
    );
    await _reload();
    return audit;
  }

  /// Host `make reset-process-library`: wipe DB then force re-import bundled.
  Future<ProcessLibraryImportResult> resetAndReimportBundled() async {
    await repository.clearAll();
    final result = await importer.importBundled(force: true);
    await _reload();
    return result;
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
