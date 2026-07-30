import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/legacy_static_data_reader.dart';
import 'package:lws_hmi/platform/os_paths.dart';

typedef LegacyStaticDataFileReader = Future<LegacyStaticDataImport?> Function(
  String path,
);

/// Imports a service-exported lws-ui `static_data` database before HMI starts.
///
/// Android application data is not directly readable by the Linux HMI. A
/// migration/service tool must therefore place one consistent, checkpointed
/// SQLite copy at [defaultLegacyDbPath]. An absent file is a normal fresh
/// install and produces no write.
final class LegacyStaticDataMigrator {
  LegacyStaticDataMigrator({
    required StatsAggregateRepository repository,
    this.sourcePath = defaultLegacyDbPath,
    LegacyStaticDataFileReader? readFile,
  })  : _repository = repository,
        _readFile = readFile ?? LegacyStaticDataReader.readFile;

  static const defaultLegacyDbPath =
      '${OsPaths.varHmi}/legacy/lws-ui-static-data.db';

  final StatsAggregateRepository _repository;
  final String sourcePath;
  final LegacyStaticDataFileReader _readFile;

  Future<LegacyStaticDataMigrationResult?> run() async {
    try {
      final legacy = await _readFile(sourcePath);
      if (legacy == null) {
        return null;
      }
      return _repository.migrateFromLegacyStaticData(legacy);
    } catch (error) {
      // A malformed service export must never prevent a fresh HMI from
      // starting. The aggregate is left untouched because repository migration
      // is transactional.
      debugPrint('statistics: legacy static_data migration skipped: $error');
      return null;
    }
  }
}
