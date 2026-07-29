import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_models.dart';
import 'package:lws_hmi/features/process_video/domain/process_video_repository.dart';
import 'package:lws_hmi/platform/os_paths.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite index at `/var/lib/hmi/process-videos.db` (→ `/userdata/hmi/`).
final class SqliteProcessVideoRepository implements ProcessVideoRepository {
  SqliteProcessVideoRepository({
    String? dbPath,
    Database? database,
  }) : dbPath = dbPath ?? '${OsPaths.varHmi}/$kDbFileName' {
    if (database != null) {
      _db = database;
      _ensureSchema(_db!);
      _loaded = true;
    }
  }

  static const kDbFileName = 'process-videos.db';
  static const kTable = 'process_videos';
  static const schemaVersion = 1;

  final String dbPath;

  Database? _db;
  bool _loaded = false;
  bool _openFailed = false;

  @override
  Future<void> open() async {
    await _ensureOpen();
  }

  Future<bool> _ensureOpen() async {
    if (_loaded && _db != null) {
      return true;
    }
    if (_openFailed) {
      return false;
    }
    try {
      await File(dbPath).parent.create(recursive: true);
      _db = sqlite3.open(dbPath);
      _ensureSchema(_db!);
      _loaded = true;
      return true;
    } catch (e) {
      _openFailed = true;
      _db = null;
      debugPrint('process-video sqlite: open failed: $e');
      return false;
    }
  }

  static void _ensureSchema(Database db) {
    final version = db.select('PRAGMA user_version').first['user_version'] as int;
    if (version >= schemaVersion) {
      return;
    }
    db.execute('''
CREATE TABLE IF NOT EXISTS $kTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  video_id TEXT NOT NULL,
  video_path TEXT NOT NULL,
  process_type INTEGER NOT NULL,
  material_type INTEGER,
  process_parameters_json TEXT NOT NULL,
  file_size INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  resolution TEXT,
  create_time_ms INTEGER NOT NULL,
  upload_status INTEGER NOT NULL DEFAULT 0,
  upload_progress INTEGER NOT NULL DEFAULT 0,
  cover_url TEXT,
  video_url TEXT
);
''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_process_videos_create_time '
      'ON $kTable (create_time_ms DESC);',
    );
    db.execute('PRAGMA user_version = $schemaVersion');
  }

  @override
  Future<ProcessVideoRecord> insert(ProcessVideoRecord record) async {
    if (!await _ensureOpen()) {
      throw StateError('process-video sqlite unavailable');
    }
    final db = _db!;
    db.execute(
      '''
INSERT INTO $kTable (
  video_id, video_path, process_type, material_type, process_parameters_json,
  file_size, duration_ms, resolution, create_time_ms,
  upload_status, upload_progress, cover_url, video_url
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        record.videoId,
        record.videoPath,
        record.processType.wireValue,
        record.materialType?.storageValue,
        record.processParametersJson,
        record.fileSize,
        record.durationMs,
        record.resolution,
        record.createTimeMs,
        record.uploadStatus,
        record.uploadProgress,
        record.coverUrl,
        record.videoUrl,
      ],
    );
    final id = db.lastInsertRowId;
    return ProcessVideoRecord(
      id: id,
      videoId: record.videoId,
      videoPath: record.videoPath,
      processType: record.processType,
      materialType: record.materialType,
      processParametersJson: record.processParametersJson,
      fileSize: record.fileSize,
      durationMs: record.durationMs,
      resolution: record.resolution,
      createTimeMs: record.createTimeMs,
      uploadStatus: record.uploadStatus,
      uploadProgress: record.uploadProgress,
      coverUrl: record.coverUrl,
      videoUrl: record.videoUrl,
    );
  }

  @override
  Future<List<ProcessVideoRecord>> list({int limit = 10, int offset = 0}) async {
    try {
      if (!await _ensureOpen()) {
        return const [];
      }
      final rows = _db!.select(
        'SELECT * FROM $kTable ORDER BY create_time_ms DESC LIMIT ? OFFSET ?',
        [limit, offset],
      );
      return [for (final row in rows) _fromRow(row)];
    } catch (e) {
      debugPrint('process-video sqlite: list failed: $e');
      return const [];
    }
  }

  @override
  Future<int> count() async {
    try {
      if (!await _ensureOpen()) {
        return 0;
      }
      final row = _db!.select('SELECT COUNT(*) AS c FROM $kTable').first;
      return row['c'] as int;
    } catch (e) {
      debugPrint('process-video sqlite: count failed: $e');
      return 0;
    }
  }

  @override
  Future<ProcessVideoRecord?> getById(int id) async {
    try {
      if (!await _ensureOpen()) {
        return null;
      }
      final rows = _db!.select('SELECT * FROM $kTable WHERE id = ?', [id]);
      if (rows.isEmpty) {
        return null;
      }
      return _fromRow(rows.first);
    } catch (e) {
      debugPrint('process-video sqlite: getById failed: $e');
      return null;
    }
  }

  @override
  Future<bool> deleteById(int id) async {
    try {
      if (!await _ensureOpen()) {
        return false;
      }
      final existing = await getById(id);
      if (existing == null) {
        return false;
      }
      _db!.execute('DELETE FROM $kTable WHERE id = ?', [id]);
      try {
        final file = File(existing.videoPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('process-video: file delete soft-fail: $e');
      }
      return true;
    } catch (e) {
      debugPrint('process-video sqlite: deleteById failed: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
    _loaded = false;
  }

  static ProcessVideoRecord _fromRow(Row row) {
    final materialRaw = row['material_type'] as int?;
    return ProcessVideoRecord(
      id: row['id'] as int,
      videoId: row['video_id'] as String,
      videoPath: row['video_path'] as String,
      processType: ProcessType.fromWireValue(row['process_type'] as int),
      materialType: materialRaw == null
          ? null
          : MaterialType.fromStorageValue(materialRaw),
      processParametersJson: row['process_parameters_json'] as String,
      fileSize: row['file_size'] as int,
      durationMs: row['duration_ms'] as int,
      resolution: row['resolution'] as String?,
      createTimeMs: row['create_time_ms'] as int,
      uploadStatus: (row['upload_status'] as int?) ?? 0,
      uploadProgress: (row['upload_progress'] as int?) ?? 0,
      coverUrl: row['cover_url'] as String?,
      videoUrl: row['video_url'] as String?,
    );
  }
}
