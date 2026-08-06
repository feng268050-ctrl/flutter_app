import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/platform/os_paths.dart';
import 'package:sqlite3/sqlite3.dart';

/// Single-row aggregate database at `/var/lib/hmi/hmi-stats.db`.
final class SqliteStatsAggregateRepository implements StatsAggregateRepository {
  SqliteStatsAggregateRepository({String? dbPath, Database? database})
      : dbPath = dbPath ?? '${OsPaths.varHmi}/$kDbFileName' {
    if (database != null) {
      _db = database;
      _ensureSchema(_db!);
      _loaded = true;
    }
  }

  static const kDbFileName = 'hmi-stats.db';
  static const kTable = 'stats_aggregate';
  static const schemaVersion = 2;

  static const _materialSessionCountColumns = <int, String>{
    1: 'stainless_steel_session_count_total',
    2: 'carbon_steel_session_count_total',
    3: 'galvanized_sheet_session_count_total',
    4: 'aluminum_alloy_session_count_total',
    5: 'brass_session_count_total',
    6: 'custom_material_session_count_total',
  };

  final String dbPath;
  Database? _db;
  bool _loaded = false;
  bool _openFailed = false;

  @override
  Future<void> open() async {
    await _ensureOpen();
  }

  Future<bool> _ensureOpen() async {
    if (_loaded && _db != null) return true;
    if (_openFailed) return false;
    try {
      await File(dbPath).parent.create(recursive: true);
      _db = sqlite3.open(dbPath);
      _ensureSchema(_db!);
      _loaded = true;
      return true;
    } catch (error) {
      _openFailed = true;
      _db = null;
      debugPrint('stats aggregate sqlite: open failed: $error');
      return false;
    }
  }

  static void _ensureSchema(Database db) {
    db.execute('''
CREATE TABLE IF NOT EXISTS $kTable (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  schema_version INTEGER NOT NULL DEFAULT $schemaVersion,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  last_reset_at_ms INTEGER NOT NULL DEFAULT 0,
  last_settled_session_id TEXT,
  weld_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (weld_seconds_total >= 0),
  cut_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (cut_seconds_total >= 0),
  clean_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (clean_seconds_total >= 0),
  laser_on_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (laser_on_seconds_total >= 0),
  job_runtime_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (job_runtime_seconds_total >= 0),
  wire_feed_length_mm_total INTEGER NOT NULL DEFAULT 0 CHECK (wire_feed_length_mm_total >= 0),
  weld_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (weld_session_count_total >= 0),
  cut_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (cut_session_count_total >= 0),
  clean_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (clean_session_count_total >= 0),
  laser_enable_count_total INTEGER NOT NULL DEFAULT 0 CHECK (laser_enable_count_total >= 0),
  last_session_mode_type INTEGER,
  last_session_duration_seconds INTEGER,
  last_session_wire_feed_speed_mm_s REAL,
  last_session_material_type INTEGER,
  last_session_ended_at_ms INTEGER,
  week_anchor_started_at_ms INTEGER NOT NULL DEFAULT 0,
  week_anchor_laser_on_seconds_total INTEGER NOT NULL DEFAULT 0,
  prev_week_anchor_started_at_ms INTEGER NOT NULL DEFAULT 0,
  prev_week_anchor_laser_on_seconds_total INTEGER NOT NULL DEFAULT 0,
  favorite_material_type INTEGER,
  favorite_material_updated_at_ms INTEGER,
  stainless_steel_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (stainless_steel_session_count_total >= 0),
  carbon_steel_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (carbon_steel_session_count_total >= 0),
  galvanized_sheet_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (galvanized_sheet_session_count_total >= 0),
  aluminum_alloy_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (aluminum_alloy_session_count_total >= 0),
  brass_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (brass_session_count_total >= 0),
  custom_material_session_count_total INTEGER NOT NULL DEFAULT 0 CHECK (custom_material_session_count_total >= 0),
  legacy_static_data_imported_at_ms INTEGER,
  legacy_static_data_import_source TEXT,
  active_session_id TEXT,
  active_session_started_at_ms INTEGER,
  active_session_mode_type INTEGER,
  active_session_auto_wire_feed_enabled INTEGER,
  active_session_auto_wire_feed_speed_mm_s REAL,
  active_session_material_type INTEGER
);
''');
    _ensureColumn(db, 'active_session_id', 'TEXT');
    _ensureColumn(db, 'active_session_started_at_ms', 'INTEGER');
    _ensureColumn(db, 'active_session_mode_type', 'INTEGER');
    _ensureColumn(db, 'active_session_auto_wire_feed_enabled', 'INTEGER');
    _ensureColumn(
      db,
      'active_session_auto_wire_feed_speed_mm_s',
      'REAL',
    );
    _ensureColumn(db, 'active_session_material_type', 'INTEGER');
    for (final column in _materialSessionCountColumns.values) {
      _ensureColumn(db, column, 'INTEGER NOT NULL DEFAULT 0');
    }
    _ensureColumn(db, 'legacy_static_data_imported_at_ms', 'INTEGER');
    _ensureColumn(db, 'legacy_static_data_import_source', 'TEXT');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.execute(
      'INSERT OR IGNORE INTO $kTable (id, created_at_ms, updated_at_ms) VALUES (1, ?, ?)',
      [now, now],
    );
    db.execute(
      'UPDATE $kTable SET schema_version = ? WHERE schema_version < ?',
      [schemaVersion, schemaVersion],
    );
  }

  static void _ensureColumn(Database db, String name, String type) {
    final columns = db.select('PRAGMA table_info($kTable)');
    if (columns.any((row) => row['name'] == name)) {
      return;
    }
    db.execute('ALTER TABLE $kTable ADD COLUMN $name $type');
  }

  Database get _database => _db!;

  @override
  Future<StatsAggregate> load() async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    return _fromRow(
        _database.select('SELECT * FROM $kTable WHERE id = 1').first);
  }

  @override
  Future<void> startWorkSession(WorkSessionStartEvent event) async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    if (event.autoWireFeedSpeedMmPerSecond < 0) {
      throw ArgumentError.value(
        event.autoWireFeedSpeedMmPerSecond,
        'autoWireFeedSpeedMmPerSecond',
      );
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _database.execute('''
UPDATE $kTable SET
  active_session_id = ?,
  active_session_started_at_ms = ?,
  active_session_mode_type = ?,
  active_session_auto_wire_feed_enabled = ?,
  active_session_auto_wire_feed_speed_mm_s = ?,
  active_session_material_type = ?,
  laser_enable_count_total = laser_enable_count_total + 1,
  updated_at_ms = ?
WHERE id = 1
''', [
      event.sessionId,
      event.startedAtMs ?? now,
      event.modeType,
      event.autoWireFeedEnabled ? 1 : 0,
      event.autoWireFeedSpeedMmPerSecond,
      event.materialType,
      now,
    ]);
  }

  @override
  Future<bool> settleActiveWorkSession({DateTime? endedAt}) async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    final db = _database;
    final endedAtMs =
        (endedAt ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final updatedAtMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.execute('BEGIN IMMEDIATE');
    try {
      final row = db.select('''
SELECT active_session_id, active_session_started_at_ms,
  active_session_mode_type, active_session_auto_wire_feed_enabled,
  active_session_auto_wire_feed_speed_mm_s, active_session_material_type
FROM $kTable WHERE id = 1
''').first;
      final sessionId = row['active_session_id'] as String?;
      final startedAtMs = row['active_session_started_at_ms'] as int?;
      if (sessionId == null || startedAtMs == null) {
        db.execute('ROLLBACK');
        return false;
      }
      final durationSeconds =
          ((endedAtMs - startedAtMs) ~/ 1000).clamp(0, 1 << 31);
      final modeType = row['active_session_mode_type'] as int? ?? 0;
      final speed =
          (row['active_session_auto_wire_feed_speed_mm_s'] as num? ?? 0)
              .toDouble();
      final materialType = row['active_session_material_type'] as int?;
      // lws-ui `StaticDataViewModel.weldStop` weld case:
      //   consumableTimeLength += sessionSeconds * wireFeedSpeedMmPerS
      // (laser-enable→disable duration × process auto wire-feed speed).
      // Cut / clean never add wire. Manual jog is excluded by not using this
      // session path for Feed/Retract.
      final wireLengthMm =
          modeType == 1 ? (durationSeconds * speed).round() : 0;
      final lastSettled = db
          .select(
            'SELECT last_settled_session_id FROM $kTable WHERE id = 1',
          )
          .first['last_settled_session_id'];
      final settled = lastSettled != sessionId;
      if (settled) {
        final modeColumn = switch (modeType) {
          1 => 'weld_seconds_total',
          2 => 'cut_seconds_total',
          3 => 'clean_seconds_total',
          _ => null,
        };
        final countColumn = switch (modeType) {
          1 => 'weld_session_count_total',
          2 => 'cut_session_count_total',
          3 => 'clean_session_count_total',
          _ => null,
        };
        final updates = <String>[
          'laser_on_seconds_total = laser_on_seconds_total + ?',
          'last_settled_session_id = ?',
          'last_session_mode_type = ?',
          'last_session_duration_seconds = ?',
          'last_session_wire_feed_speed_mm_s = ?',
          'last_session_material_type = ?',
          'last_session_ended_at_ms = ?',
          'updated_at_ms = ?',
        ];
        final args = <Object?>[
          durationSeconds,
          sessionId,
          modeType,
          durationSeconds,
          speed,
          materialType,
          endedAtMs,
          updatedAtMs,
        ];
        if (modeColumn != null) {
          updates.insert(0, '$modeColumn = $modeColumn + ?');
          args.insert(0, durationSeconds);
        }
        if (countColumn != null) {
          updates.insert(1, '$countColumn = $countColumn + 1');
        }
        if (wireLengthMm > 0) {
          updates.insert(
            1,
            'wire_feed_length_mm_total = wire_feed_length_mm_total + ?',
          );
          args.insert(1, wireLengthMm);
        }
        final materialColumn = materialType == null
            ? null
            : _materialSessionCountColumns[materialType];
        if (materialColumn != null) {
          updates.insert(1, '$materialColumn = $materialColumn + 1');
        }
        db.execute(
          'UPDATE $kTable SET ${updates.join(', ')} WHERE id = 1',
          args,
        );
        if (materialColumn != null) {
          _refreshFavoriteMaterial(
            db,
            preferredMaterialType: materialType!,
            updatedAtMs: updatedAtMs,
          );
        }
      }
      db.execute('''
UPDATE $kTable SET
  active_session_id = NULL,
  active_session_started_at_ms = NULL,
  active_session_mode_type = NULL,
  active_session_auto_wire_feed_enabled = NULL,
  active_session_auto_wire_feed_speed_mm_s = NULL,
  active_session_material_type = NULL
WHERE id = 1
''');
      db.execute('COMMIT');
      return settled;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<bool> recordWorkStop(WorkStopEvent event) async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    if (event.durationSeconds < 0 ||
        event.laserOnSeconds < 0 ||
        event.autoWireFeedSeconds < 0 ||
        event.autoWireFeedSpeedMmPerSecond < 0) {
      throw ArgumentError('work-stop durations and speed must be non-negative');
    }
    final db = _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final endedAt = event.endedAtMs ?? now;
    final modeColumn = switch (event.modeType) {
      1 => 'weld_seconds_total',
      2 => 'cut_seconds_total',
      3 => 'clean_seconds_total',
      _ => null,
    };
    final countColumn = switch (event.modeType) {
      1 => 'weld_session_count_total',
      2 => 'cut_session_count_total',
      3 => 'clean_session_count_total',
      _ => null,
    };
    final wireLengthMm = event.wireFeedLengthMm;
    db.execute('BEGIN IMMEDIATE');
    try {
      final row = db
          .select(
            'SELECT last_settled_session_id FROM $kTable WHERE id = 1',
          )
          .first;
      if (row['last_settled_session_id'] == event.sessionId) {
        db.execute('ROLLBACK');
        return false;
      }
      final updates = <String>[
        'laser_on_seconds_total = laser_on_seconds_total + ?',
        'last_settled_session_id = ?',
        'last_session_mode_type = ?',
        'last_session_duration_seconds = ?',
        'last_session_wire_feed_speed_mm_s = ?',
        'last_session_material_type = ?',
        'last_session_ended_at_ms = ?',
        'updated_at_ms = ?',
      ];
      final args = <Object?>[
        event.laserOnSeconds,
        event.sessionId,
        event.modeType,
        event.durationSeconds,
        event.autoWireFeedSpeedMmPerSecond,
        event.materialType,
        endedAt,
        now,
      ];
      if (modeColumn != null) {
        updates.insert(0, '$modeColumn = $modeColumn + ?');
        args.insert(0, event.durationSeconds);
      }
      if (countColumn != null) {
        updates.insert(1, '$countColumn = $countColumn + 1');
      }
      if (wireLengthMm > 0) {
        updates.insert(
            1, 'wire_feed_length_mm_total = wire_feed_length_mm_total + ?');
        args.insert(1, wireLengthMm);
      }
      final materialColumn = event.materialType == null
          ? null
          : _materialSessionCountColumns[event.materialType!];
      if (materialColumn != null) {
        updates.insert(1, '$materialColumn = $materialColumn + 1');
      }
      db.execute('UPDATE $kTable SET ${updates.join(', ')} WHERE id = 1', args);
      if (materialColumn != null) {
        _refreshFavoriteMaterial(
          db,
          preferredMaterialType: event.materialType!,
          updatedAtMs: now,
        );
      }
      db.execute('COMMIT');
      return true;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<void> addJobRuntimeSeconds(int seconds) async {
    if (seconds < 0) throw ArgumentError.value(seconds, 'seconds');
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    _database.execute(
      'UPDATE $kTable SET job_runtime_seconds_total = job_runtime_seconds_total + ?, updated_at_ms = ? WHERE id = 1',
      [seconds, DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> recordLaserEnable() async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    _database.execute(
      'UPDATE $kTable SET laser_enable_count_total = laser_enable_count_total + 1, updated_at_ms = ? WHERE id = 1',
      [DateTime.now().toUtc().millisecondsSinceEpoch],
    );
  }

  @override
  Future<void> refreshWeekAnchors(DateTime now) async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    final currentStart = _startOfWeek(now).millisecondsSinceEpoch;
    final db = _database;
    final current = db
        .select(
          'SELECT week_anchor_started_at_ms FROM $kTable WHERE id = 1',
        )
        .first['week_anchor_started_at_ms'] as int;
    if (current == 0) {
      db.execute(
        'UPDATE $kTable SET week_anchor_started_at_ms = ?, week_anchor_laser_on_seconds_total = laser_on_seconds_total, updated_at_ms = ? WHERE id = 1',
        [currentStart, DateTime.now().toUtc().millisecondsSinceEpoch],
      );
    } else if (currentStart > current) {
      db.execute('''
UPDATE $kTable SET
  prev_week_anchor_started_at_ms = week_anchor_started_at_ms,
  prev_week_anchor_laser_on_seconds_total = week_anchor_laser_on_seconds_total,
  week_anchor_started_at_ms = ?,
  week_anchor_laser_on_seconds_total = laser_on_seconds_total,
  updated_at_ms = ?
WHERE id = 1
''', [currentStart, DateTime.now().toUtc().millisecondsSinceEpoch]);
    }
  }

  @override
  Future<LegacyStaticDataMigrationResult> migrateFromLegacyStaticData(
    LegacyStaticDataImport legacy,
  ) async {
    if (!await _ensureOpen()) {
      throw StateError('stats aggregate sqlite unavailable');
    }
    _validateLegacyImport(legacy);
    final db = _database;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    db.execute('BEGIN IMMEDIATE');
    try {
      final row = db.select('''
SELECT legacy_static_data_imported_at_ms,
  weld_seconds_total, cut_seconds_total, clean_seconds_total,
  laser_on_seconds_total, job_runtime_seconds_total, wire_feed_length_mm_total,
  weld_session_count_total, cut_session_count_total,
  clean_session_count_total, laser_enable_count_total
FROM $kTable WHERE id = 1
''').first;
      if (row['legacy_static_data_imported_at_ms'] != null) {
        db.execute('ROLLBACK');
        return LegacyStaticDataMigrationResult.alreadyImported;
      }
      if (_hasAggregateData(row)) {
        db.execute('ROLLBACK');
        return LegacyStaticDataMigrationResult.targetNotEmpty;
      }

      final hasWeekAnchors = legacy.weekAnchorStartedAtMs != null;
      final laserOnSeconds = legacy.weldSecondsTotal +
          legacy.cutSecondsTotal +
          legacy.cleanSecondsTotal;
      db.execute('''
UPDATE $kTable SET
  weld_seconds_total = ?,
  cut_seconds_total = ?,
  clean_seconds_total = ?,
  laser_on_seconds_total = ?,
  job_runtime_seconds_total = ?,
  wire_feed_length_mm_total = ?,
  week_anchor_started_at_ms = ?,
  week_anchor_laser_on_seconds_total = ?,
  prev_week_anchor_started_at_ms = ?,
  prev_week_anchor_laser_on_seconds_total = ?,
  favorite_material_type = ?,
  favorite_material_updated_at_ms = ?,
  legacy_static_data_imported_at_ms = ?,
  legacy_static_data_import_source = ?,
  updated_at_ms = ?
WHERE id = 1
''', [
        legacy.weldSecondsTotal,
        legacy.cutSecondsTotal,
        legacy.cleanSecondsTotal,
        laserOnSeconds,
        legacy.jobRuntimeSecondsTotal,
        legacy.wireFeedLengthMmTotal ?? 0,
        hasWeekAnchors ? legacy.weekAnchorStartedAtMs : 0,
        hasWeekAnchors ? legacy.weekAnchorLaserOnSecondsTotal : 0,
        hasWeekAnchors ? legacy.prevWeekAnchorStartedAtMs : 0,
        hasWeekAnchors ? legacy.prevWeekAnchorLaserOnSecondsTotal : 0,
        legacy.favoriteMaterialType,
        legacy.favoriteMaterialType == null ? null : now,
        now,
        legacy.source,
        now,
      ]);
      db.execute('COMMIT');
      return LegacyStaticDataMigrationResult.imported;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static bool _hasAggregateData(Row row) => <String>[
        'weld_seconds_total',
        'cut_seconds_total',
        'clean_seconds_total',
        'laser_on_seconds_total',
        'job_runtime_seconds_total',
        'wire_feed_length_mm_total',
        'weld_session_count_total',
        'cut_session_count_total',
        'clean_session_count_total',
        'laser_enable_count_total',
      ].any((column) => (row[column] as int) > 0);

  static void _validateLegacyImport(LegacyStaticDataImport legacy) {
    if (legacy.source.trim().isEmpty) {
      throw ArgumentError.value(legacy.source, 'source');
    }
    final values = <int?>[
      legacy.weldSecondsTotal,
      legacy.cutSecondsTotal,
      legacy.cleanSecondsTotal,
      legacy.jobRuntimeSecondsTotal,
      legacy.wireFeedLengthMmTotal,
    ];
    if (values.any((value) => value != null && value < 0)) {
      throw ArgumentError('legacy statistics must be non-negative');
    }
    final favorite = legacy.favoriteMaterialType;
    if (favorite != null &&
        !_materialSessionCountColumns.containsKey(favorite)) {
      throw ArgumentError.value(favorite, 'favoriteMaterialType');
    }
    final weekValues = <int?>[
      legacy.weekAnchorStartedAtMs,
      legacy.weekAnchorLaserOnSecondsTotal,
      legacy.prevWeekAnchorStartedAtMs,
      legacy.prevWeekAnchorLaserOnSecondsTotal,
    ];
    final presentWeekValues = weekValues.whereType<int>().length;
    if (presentWeekValues != 0 && presentWeekValues != weekValues.length) {
      throw ArgumentError(
        'legacy week anchors must be supplied as one verified set',
      );
    }
    if (weekValues.any((value) => value != null && value < 0)) {
      throw ArgumentError('legacy week anchors must be non-negative');
    }
  }

  static void _refreshFavoriteMaterial(
    Database db, {
    required int preferredMaterialType,
    required int updatedAtMs,
  }) {
    final row = db
        .select('SELECT ${_materialSessionCountColumns.values.join(', ')} '
            'FROM $kTable WHERE id = 1')
        .first;
    var favoriteType = preferredMaterialType;
    var maxCount = -1;
    for (final entry in _materialSessionCountColumns.entries) {
      final count = row[entry.value] as int;
      if (count > maxCount ||
          (count == maxCount && entry.key == preferredMaterialType)) {
        maxCount = count;
        favoriteType = entry.key;
      }
    }
    db.execute(
      'UPDATE $kTable SET favorite_material_type = ?, '
      'favorite_material_updated_at_ms = ?, updated_at_ms = ? WHERE id = 1',
      [favoriteType, updatedAtMs, updatedAtMs],
    );
  }

  static DateTime _startOfWeek(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return local.subtract(Duration(days: local.weekday - DateTime.monday));
  }

  static StatsAggregate _fromRow(Row row) => StatsAggregate(
        schemaVersion: row['schema_version'] as int,
        createdAtMs: row['created_at_ms'] as int,
        updatedAtMs: row['updated_at_ms'] as int,
        lastResetAtMs: row['last_reset_at_ms'] as int,
        lastSettledSessionId: row['last_settled_session_id'] as String?,
        weldSecondsTotal: row['weld_seconds_total'] as int,
        cutSecondsTotal: row['cut_seconds_total'] as int,
        cleanSecondsTotal: row['clean_seconds_total'] as int,
        laserOnSecondsTotal: row['laser_on_seconds_total'] as int,
        jobRuntimeSecondsTotal: row['job_runtime_seconds_total'] as int,
        wireFeedLengthMmTotal: row['wire_feed_length_mm_total'] as int,
        weldSessionCountTotal: row['weld_session_count_total'] as int,
        cutSessionCountTotal: row['cut_session_count_total'] as int,
        cleanSessionCountTotal: row['clean_session_count_total'] as int,
        laserEnableCountTotal: row['laser_enable_count_total'] as int,
        lastSessionModeType: row['last_session_mode_type'] as int?,
        lastSessionDurationSeconds:
            row['last_session_duration_seconds'] as int?,
        lastSessionWireFeedSpeedMmPerSecond:
            (row['last_session_wire_feed_speed_mm_s'] as num?)?.toDouble(),
        lastSessionMaterialType: row['last_session_material_type'] as int?,
        lastSessionEndedAtMs: row['last_session_ended_at_ms'] as int?,
        weekAnchorStartedAtMs: row['week_anchor_started_at_ms'] as int,
        weekAnchorLaserOnSecondsTotal:
            row['week_anchor_laser_on_seconds_total'] as int,
        prevWeekAnchorStartedAtMs: row['prev_week_anchor_started_at_ms'] as int,
        prevWeekAnchorLaserOnSecondsTotal:
            row['prev_week_anchor_laser_on_seconds_total'] as int,
        favoriteMaterialType: row['favorite_material_type'] as int?,
        favoriteMaterialUpdatedAtMs:
            row['favorite_material_updated_at_ms'] as int?,
        stainlessSteelSessionCountTotal:
            row['stainless_steel_session_count_total'] as int,
        carbonSteelSessionCountTotal:
            row['carbon_steel_session_count_total'] as int,
        galvanizedSheetSessionCountTotal:
            row['galvanized_sheet_session_count_total'] as int,
        aluminumAlloySessionCountTotal:
            row['aluminum_alloy_session_count_total'] as int,
        brassSessionCountTotal: row['brass_session_count_total'] as int,
        customMaterialSessionCountTotal:
            row['custom_material_session_count_total'] as int,
        legacyStaticDataImportedAtMs:
            row['legacy_static_data_imported_at_ms'] as int?,
        legacyStaticDataImportSource:
            row['legacy_static_data_import_source'] as String?,
      );

  @override
  Future<void> close() async {
    _db?.dispose();
    _db = null;
    _loaded = false;
  }
}
