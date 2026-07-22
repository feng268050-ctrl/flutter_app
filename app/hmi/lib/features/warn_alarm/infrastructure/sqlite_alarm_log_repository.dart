import 'dart:async';
import 'dart:io';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/warn_alarm/catalog/product_alarm_catalog.dart';
import 'package:lws_hmi/platform/os_paths.dart';
import 'package:sqlite3/sqlite3.dart';

/// Warn severity ints (lws-ui `WarnLevelConstant` parity).
abstract final class WarnLevel {
  static const serious = 1;
  static const waitConfirm = 2;
  static const ignore = 3;
  static const remove = 4;
}

/// SQLite history at `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`).
///
/// Single table [kAlarmLogsTable]. Insert is one row per rising-edge call from
/// `cyber_alarm` (no repository-level time-window dedup — Modbus / coordinator
/// own onset policy). Newest-first by [timestamp]. UI formats as
/// `YYYY-MM-DD HH:mm`.
final class SqliteAlarmLogRepository implements AlarmLogRepository {
  SqliteAlarmLogRepository({
    String? dbPath,
    this.pruneOlderThan = const Duration(days: 90),
    Database? database,
  }) : dbPath = dbPath ?? '${OsPaths.varHmi}/$kAlarmLogsDbFileName' {
    if (database != null) {
      _db = database;
      _ensureSchema(_db!);
      _pruneOld(_db!);
      _loaded = true;
    }
  }

  /// On-disk name under [OsPaths.varHmi] / `/userdata/hmi/`.
  static const kAlarmLogsDbFileName = 'alarm-logs.db';

  /// Sole table in [kAlarmLogsDbFileName].
  static const kAlarmLogsTable = 'alarm_logs';

  final String dbPath;
  final Duration pruneOlderThan;

  Database? _db;
  bool _loaded = false;
  final _ctrl = StreamController<List<AlarmLogEntry>>.broadcast();

  Future<void> _ensureOpen() async {
    if (_loaded && _db != null) {
      return;
    }
    try {
      await File(dbPath).parent.create(recursive: true);
      _db = sqlite3.open(dbPath);
      _ensureSchema(_db!);
      _pruneOld(_db!);
      _loaded = true;
    } catch (e) {
      debugPrint('alarm-log sqlite: open failed: $e');
      rethrow;
    }
  }

  static void _ensureSchema(Database db) {
    db.execute('''
CREATE TABLE IF NOT EXISTS $kAlarmLogsTable (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT,
  content TEXT,
  timestamp INTEGER,
  level INTEGER
);
''');
  }

  void _pruneOld(Database db) {
    final cutoff =
        DateTime.now().toUtc().millisecondsSinceEpoch - pruneOlderThan.inMilliseconds;
    db.execute('DELETE FROM $kAlarmLogsTable WHERE timestamp < ?', [cutoff]);
  }

  static int levelForCode(String code) {
    switch (ProductAlarmCatalog.severityFor(code)) {
      case AlarmSeverity.critical:
      case AlarmSeverity.high:
        return WarnLevel.serious;
      case AlarmSeverity.medium:
        return WarnLevel.waitConfirm;
      case AlarmSeverity.low:
        return WarnLevel.ignore;
      case AlarmSeverity.unknown:
        return WarnLevel.waitConfirm;
    }
  }

  List<AlarmLogEntry> _querySync({int? limit}) {
    final db = _db;
    if (db == null) {
      return const [];
    }
    final rows = limit == null
        ? db.select(
            'SELECT code, content, timestamp FROM $kAlarmLogsTable '
            'ORDER BY timestamp DESC',
          )
        : db.select(
            'SELECT code, content, timestamp FROM $kAlarmLogsTable '
            'ORDER BY timestamp DESC LIMIT ?',
            [limit],
          );
    return [
      for (final row in rows)
        AlarmLogEntry(
          code: row['code'] as String? ?? '',
          title: row['content'] as String? ?? '',
          label: row['content'] as String?,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (row['timestamp'] as int?) ?? 0,
            isUtc: true,
          ),
        ),
    ];
  }

  void _emit() {
    if (!_ctrl.isClosed) {
      _ctrl.add(_querySync());
    }
  }

  @override
  Future<void> insertRising(AlarmLogEntry entry) async {
    await _ensureOpen();
    final db = _db!;
    final nowMs = entry.timestamp.toUtc().millisecondsSinceEpoch;
    db.execute(
      'INSERT INTO $kAlarmLogsTable (code, content, timestamp, level) '
      'VALUES (?, ?, ?, ?)',
      [
        entry.code,
        entry.displayLabel,
        nowMs,
        levelForCode(entry.code),
      ],
    );
    _emit();
  }

  @override
  Future<List<AlarmLogEntry>> query({int? limit}) async {
    await _ensureOpen();
    return _querySync(limit: limit);
  }

  @override
  Future<void> clear() async {
    await _ensureOpen();
    _db!.execute('DELETE FROM $kAlarmLogsTable');
    _emit();
  }

  @override
  Stream<List<AlarmLogEntry>> watch({int? limit}) async* {
    await _ensureOpen();
    yield _querySync(limit: limit);
    yield* _ctrl.stream.map((_) => _querySync(limit: limit));
  }

  Future<void> dispose() async {
    await _ctrl.close();
    _db?.dispose();
    _db = null;
    _loaded = false;
  }
}
