import 'dart:io';

import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:sqlite3/sqlite3.dart';

/// Reads only the semantically confirmed part of a copied lws-ui Room DB.
///
/// The caller must supply a consistent SQLite export (including a checkpointed
/// WAL). `consumableTimeLength` and the legacy week fields deliberately remain
/// unread because the old table does not carry enough unit/semantic metadata to
/// migrate them safely.
final class LegacyStaticDataReader {
  static const _table = 'static_data';
  static const _requiredColumns = <String>{
    'weldingTimeLength',
    'cuttingTimeLength',
    'washTimeLength',
    'jobTimeLength',
    'commonUse',
  };

  static Future<LegacyStaticDataImport?> readFile(String dbPath) async {
    final file = File(dbPath);
    if (!await file.exists()) {
      return null;
    }
    Database? db;
    try {
      db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      final columns = db
          .select('PRAGMA table_info($_table)')
          .map((row) => row['name'] as String)
          .toSet();
      final missing = _requiredColumns.difference(columns);
      if (missing.isNotEmpty) {
        throw FormatException(
          'legacy static_data is missing: ${missing.join(', ')}',
        );
      }
      final rows = db.select('SELECT * FROM $_table LIMIT 2');
      if (rows.isEmpty) {
        return null;
      }
      if (rows.length != 1) {
        throw FormatException(
            'legacy static_data must contain exactly one row');
      }
      final row = rows.single;
      final commonUse = _optionalKnownMaterial(row, 'commonUse');
      final stat = await file.stat();
      return LegacyStaticDataImport(
        source:
            'lws-ui-static-data:${stat.size}:${stat.modified.toUtc().millisecondsSinceEpoch}',
        weldSecondsTotal: _requiredNonNegativeInt(row, 'weldingTimeLength'),
        cutSecondsTotal: _requiredNonNegativeInt(row, 'cuttingTimeLength'),
        cleanSecondsTotal: _requiredNonNegativeInt(row, 'washTimeLength'),
        jobRuntimeSecondsTotal: _requiredNonNegativeInt(row, 'jobTimeLength'),
        favoriteMaterialType: commonUse,
      );
    } finally {
      db?.dispose();
    }
  }

  static int _requiredNonNegativeInt(Row row, String column) {
    final value = row[column];
    if (value is int && value >= 0) {
      return value;
    }
    if (value is num && value >= 0 && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('legacy $column must be a non-negative integer');
  }

  static int? _optionalKnownMaterial(Row row, String column) {
    final value = row[column];
    if (value == null) {
      return null;
    }
    final material = _requiredNonNegativeInt(row, column);
    if (material < 1 || material > 6) {
      throw FormatException('legacy $column has unknown material: $material');
    }
    return material;
  }
}
