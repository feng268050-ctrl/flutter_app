import 'dart:io';

import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_repository.dart';
import 'package:lws_hmi/platform/os_paths.dart';
import 'package:sqlite3/sqlite3.dart';

final class SqliteProcessLibraryRepository implements ProcessLibraryRepository {
  static const schemaVersion = 1;

  SqliteProcessLibraryRepository({
    String? dbPath,
    Database? database,
  })  : dbPath = dbPath ?? '${OsPaths.varHmi}/process-library.db',
        _db = database;

  final String dbPath;
  Database? _db;
  bool _ownsDatabase = false;

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Process library database is not open');
    }
    return db;
  }

  @override
  Future<void> open() async {
    if (_db != null) {
      _configure(_db!);
      _ensureSchema(_db!);
      return;
    }
    await File(dbPath).parent.create(recursive: true);
    _db = sqlite3.open(dbPath);
    _ownsDatabase = true;
    _configure(_db!);
    _ensureSchema(_db!);
  }

  static void _configure(Database db) {
    db.execute('PRAGMA foreign_keys = ON');
    db.select('PRAGMA journal_mode = WAL');
  }

  static void _ensureSchema(Database db) {
    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version > schemaVersion) {
      throw StateError(
        'Process library schema $version is newer than $schemaVersion',
      );
    }
    final parameterColumns = ProcessParameterCatalog.specs
        .map((spec) => '${spec.column} REAL')
        .join(',\n  ');
    db.execute('''
CREATE TABLE IF NOT EXISTS process_library_meta (
  source TEXT PRIMARY KEY,
  library_version TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  content_sha256 TEXT NOT NULL,
  installed_at_ms INTEGER NOT NULL,
  row_count INTEGER NOT NULL
);
''');
    db.execute('''
CREATE TABLE IF NOT EXISTS process_presets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('quick', 'engineer_preset', 'user')),
  source TEXT NOT NULL,
  is_builtin INTEGER NOT NULL CHECK (is_builtin IN (0, 1)),
  process_type INTEGER NOT NULL CHECK (process_type BETWEEN 0 AND 5),
  material_type INTEGER,
  material_name TEXT,
  thickness REAL,
  gear INTEGER,
  $parameterColumns,
  extra_json TEXT,
  library_version TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1
);
''');
    db.execute('''
CREATE INDEX IF NOT EXISTS idx_process_presets_quick_lookup
ON process_presets(kind, process_type, material_type, thickness, gear);
''');
    db.execute('''
CREATE INDEX IF NOT EXISTS idx_process_presets_engineer_list
ON process_presets(kind, process_type, name);
''');
    if (version < schemaVersion) {
      db.execute('PRAGMA user_version = $schemaVersion');
    }
  }

  @override
  Future<List<ProcessPreset>> list({
    ProcessPresetKind? kind,
    ProcessType? processType,
  }) async {
    await open();
    final clauses = <String>[];
    final args = <Object?>[];
    if (kind != null) {
      clauses.add('kind = ?');
      args.add(kind.storageValue);
    }
    if (processType != null) {
      clauses.add('process_type = ?');
      args.add(processType.wireValue);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    final rows = _database.select(
      'SELECT * FROM process_presets $where '
      'ORDER BY is_builtin DESC, name COLLATE NOCASE, id',
      args,
    );
    return rows.map(_presetFromRow).toList(growable: false);
  }

  @override
  Future<ProcessPreset?> findByUuid(String uuid) async {
    await open();
    final rows = _database.select(
      'SELECT * FROM process_presets WHERE uuid = ? LIMIT 1',
      [uuid],
    );
    return rows.isEmpty ? null : _presetFromRow(rows.first);
  }

  @override
  Future<ProcessPreset> saveUser(ProcessPreset preset) async {
    await open();
    if (preset.kind != ProcessPresetKind.user ||
        preset.isBuiltin ||
        preset.source != 'user') {
      throw ArgumentError('Only non-builtin user presets may be saved');
    }
    ProcessParameterValidator.validate(preset);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final existing = await findByUuid(preset.uuid);
    if (existing != null && existing.kind != ProcessPresetKind.user) {
      throw StateError('Built-in preset cannot be overwritten');
    }
    final saved = preset.copyWith(
      createdAtMs: existing?.createdAtMs ?? preset.createdAtMs,
      updatedAtMs: now,
      revision: existing == null ? 1 : existing.revision + 1,
    );
    _database.execute(
      _upsertSql,
      _presetArguments(saved),
    );
    return (await findByUuid(saved.uuid))!;
  }

  @override
  Future<void> deleteUser(String uuid) async {
    await open();
    _database.execute(
      "DELETE FROM process_presets WHERE uuid = ? AND kind = 'user' "
      'AND is_builtin = 0',
      [uuid],
    );
  }

  @override
  Future<ProcessLibraryMeta?> metaFor(String source) async {
    await open();
    final rows = _database.select(
      'SELECT * FROM process_library_meta WHERE source = ? LIMIT 1',
      [source],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return ProcessLibraryMeta(
      source: row['source'] as String,
      libraryVersion: row['library_version'] as String,
      schemaVersion: row['schema_version'] as int,
      contentSha256: row['content_sha256'] as String,
      installedAtMs: row['installed_at_ms'] as int,
      rowCount: row['row_count'] as int,
    );
  }

  @override
  Future<void> replaceBuiltins({
    required String source,
    required ProcessLibraryMeta meta,
    required List<ProcessPreset> presets,
    bool wipeAllBuiltinSources = false,
  }) async {
    await open();
    if (presets.any((preset) =>
        !preset.isBuiltin ||
        preset.kind == ProcessPresetKind.user ||
        preset.source != source)) {
      throw ArgumentError('Import contains invalid built-in ownership');
    }
    for (final preset in presets) {
      ProcessParameterValidator.validate(preset);
    }
    _database.execute('BEGIN IMMEDIATE');
    try {
      if (wipeAllBuiltinSources) {
        _database.execute(
          "DELETE FROM process_presets WHERE is_builtin = 1 "
          "AND kind IN ('quick', 'engineer_preset')",
        );
      } else {
        _database.execute(
          "DELETE FROM process_presets WHERE source = ? AND is_builtin = 1 "
          "AND kind IN ('quick', 'engineer_preset')",
          [source],
        );
      }
      for (final preset in presets) {
        final conflicts = _database.select(
          'SELECT source, is_builtin FROM process_presets '
          'WHERE uuid = ? LIMIT 1',
          [preset.uuid],
        );
        if (conflicts.isNotEmpty) {
          final conflict = conflicts.first;
          if ((conflict['is_builtin'] as int) == 0 ||
              conflict['source'] != source) {
            throw StateError(
              'Imported uuid conflicts with protected preset: ${preset.uuid}',
            );
          }
        }
        _database.execute(_upsertSql, _presetArguments(preset));
      }
      _database.execute('''
INSERT INTO process_library_meta (
  source, library_version, schema_version, content_sha256,
  installed_at_ms, row_count
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(source) DO UPDATE SET
  library_version = excluded.library_version,
  schema_version = excluded.schema_version,
  content_sha256 = excluded.content_sha256,
  installed_at_ms = excluded.installed_at_ms,
  row_count = excluded.row_count
''', [
        meta.source,
        meta.libraryVersion,
        meta.schemaVersion,
        meta.contentSha256,
        meta.installedAtMs,
        meta.rowCount,
      ]);
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    await open();
    _database.execute('BEGIN IMMEDIATE');
    try {
      _database.execute('DELETE FROM process_presets');
      _database.execute('DELETE FROM process_library_meta');
      _database.execute('COMMIT');
    } catch (_) {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> deleteAllUserPresets() async {
    await open();
    _database.execute(
      "DELETE FROM process_presets WHERE is_builtin = 0 OR kind = 'user'",
    );
  }

  @override
  Future<void> backupTo(String path) async {
    await open();
    final target = File(path);
    await target.parent.create(recursive: true);
    final temporary = File(
      '$path.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      _database.execute('VACUUM INTO ?', [temporary.path]);
      final check = sqlite3.open(temporary.path);
      try {
        final integrity =
            check.select('PRAGMA integrity_check').first.values.first;
        if (integrity != 'ok') {
          throw StateError('Backup integrity check failed: $integrity');
        }
      } finally {
        check.dispose();
      }
      await temporary.rename(path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> restoreFrom(String path) async {
    await open();
    final source = File(path);
    if (!await source.exists()) {
      throw ArgumentError('Backup does not exist: $path');
    }
    final escaped = path.replaceAll("'", "''");
    _database.execute("ATTACH DATABASE '$escaped' AS process_restore");
    try {
      final integrity = _database
          .select('PRAGMA process_restore.integrity_check')
          .first
          .values
          .first;
      if (integrity != 'ok') {
        throw StateError('Backup integrity check failed: $integrity');
      }
      final version = _database
          .select('PRAGMA process_restore.user_version')
          .first
          .values
          .first;
      if (version != schemaVersion) {
        throw StateError('Unsupported backup schema: $version');
      }
      _validateRestoreSchemaAndRows();
      _database.execute('BEGIN IMMEDIATE');
      try {
        _database.execute('DELETE FROM process_library_meta');
        _database.execute('DELETE FROM process_presets');
        _database.execute(
          'INSERT INTO process_library_meta SELECT * '
          'FROM process_restore.process_library_meta',
        );
        _database.execute(
          'INSERT INTO process_presets SELECT * '
          'FROM process_restore.process_presets',
        );
        _database.execute('COMMIT');
      } catch (_) {
        _database.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      _database.execute('DETACH DATABASE process_restore');
    }
  }

  void _validateRestoreSchemaAndRows() {
    Set<String> columns(String table) => _database
        .select("PRAGMA process_restore.table_info('$table')")
        .map((row) => row['name'] as String)
        .toSet();
    final missingPresets =
        _allPresetColumns.toSet().difference(columns('process_presets'));
    final missingMeta =
        _metaColumns.toSet().difference(columns('process_library_meta'));
    if (missingPresets.isNotEmpty || missingMeta.isNotEmpty) {
      throw StateError(
        'Backup schema is incomplete: '
        'presets=$missingPresets meta=$missingMeta',
      );
    }
    for (final row
        in _database.select('SELECT * FROM process_restore.process_presets')) {
      ProcessParameterValidator.validate(_presetFromRow(row));
    }
  }

  static const _metaColumns = [
    'source',
    'library_version',
    'schema_version',
    'content_sha256',
    'installed_at_ms',
    'row_count',
  ];

  static List<String> get _allPresetColumns => ['id', ..._writePresetColumns];

  static List<String> get _writePresetColumns => [
        'uuid',
        'name',
        'kind',
        'source',
        'is_builtin',
        'process_type',
        'material_type',
        'material_name',
        'thickness',
        'gear',
        ...ProcessParameterCatalog.specs.map((spec) => spec.column),
        'extra_json',
        'library_version',
        'created_at_ms',
        'updated_at_ms',
        'revision',
      ];

  static String get _upsertSql {
    final columns = _writePresetColumns;
    final updates = columns
        .where((column) => column != 'uuid' && column != 'created_at_ms')
        .map((column) => '$column = excluded.$column')
        .join(', ');
    return 'INSERT INTO process_presets (${columns.join(', ')}) '
        'VALUES (${List.filled(columns.length, '?').join(', ')}) '
        'ON CONFLICT(uuid) DO UPDATE SET $updates';
  }

  static List<Object?> _presetArguments(ProcessPreset preset) => [
        preset.uuid,
        preset.name,
        preset.kind.storageValue,
        preset.source,
        preset.isBuiltin ? 1 : 0,
        preset.processType.wireValue,
        preset.materialType?.storageValue,
        preset.materialName,
        preset.thickness,
        preset.gear,
        for (final spec in ProcessParameterCatalog.specs)
          preset.parameters.values[spec.key],
        null,
        preset.libraryVersion,
        preset.createdAtMs,
        preset.updatedAtMs,
        preset.revision,
      ];

  static ProcessPreset _presetFromRow(Row row) {
    final parameters = <String, num?>{
      for (final spec in ProcessParameterCatalog.specs)
        spec.key: row[spec.column] as num?,
    };
    return ProcessPreset(
      id: row['id'] as int,
      uuid: row['uuid'] as String,
      name: row['name'] as String,
      kind: ProcessPresetKind.parse(row['kind'] as String),
      source: row['source'] as String,
      isBuiltin: (row['is_builtin'] as int) != 0,
      processType: ProcessType.fromWireValue(row['process_type'] as int),
      materialType: row['material_type'] == null
          ? null
          : MaterialType.fromStorageValue(row['material_type'] as int),
      materialName: row['material_name'] as String?,
      thickness: (row['thickness'] as num?)?.toDouble(),
      gear: row['gear'] as int?,
      parameters: ProcessParameters(parameters),
      libraryVersion: row['library_version'] as String?,
      createdAtMs: row['created_at_ms'] as int,
      updatedAtMs: row['updated_at_ms'] as int,
      revision: row['revision'] as int,
    );
  }

  @override
  Future<void> close() async {
    if (_ownsDatabase) {
      _db?.dispose();
    }
    _db = null;
    _ownsDatabase = false;
  }
}
