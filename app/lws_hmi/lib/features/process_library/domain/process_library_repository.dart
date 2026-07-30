import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';

abstract interface class ProcessLibraryRepository {
  Future<void> open();

  Future<List<ProcessPreset>> list({
    ProcessPresetKind? kind,
    ProcessType? processType,
  });

  Future<ProcessPreset?> findByUuid(String uuid);

  Future<ProcessPreset> saveUser(ProcessPreset preset);

  Future<void> deleteUser(String uuid);

  Future<ProcessLibraryMeta?> metaFor(String source);

  Future<void> replaceBuiltins({
    required String source,
    required ProcessLibraryMeta meta,
    required List<ProcessPreset> presets,
    /// When true, delete all quick/engineer builtins regardless of prior source
    /// (cloud push parity with Android wipe of dataType 0+1).
    bool wipeAllBuiltinSources = false,
  });

  Future<void> backupTo(String path);

  Future<void> restoreFrom(String path);

  Future<void> close();
}
