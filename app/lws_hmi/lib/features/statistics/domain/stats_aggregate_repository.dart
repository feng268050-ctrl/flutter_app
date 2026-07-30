import 'stats_aggregate_models.dart';

abstract interface class StatsAggregateRepository {
  Future<void> open();

  Future<StatsAggregate> load();

  /// Persists the active work-session context and counts a successful enable.
  Future<void> startWorkSession(WorkSessionStartEvent event);

  /// Settles the active work session, if one exists, into the aggregate row.
  Future<bool> settleActiveWorkSession({DateTime? endedAt});

  /// Settles one automatic work session. Manual wire-feed jogs are excluded.
  Future<bool> recordWorkStop(WorkStopEvent event);

  Future<void> addJobRuntimeSeconds(int seconds);

  Future<void> recordLaserEnable();

  Future<void> refreshWeekAnchors(DateTime now);

  /// Imports an audited, unit-safe legacy `static_data` snapshot exactly once.
  ///
  /// The import is rejected when this aggregate already contains HMI data, so
  /// a late legacy file can never overwrite live statistics.
  Future<LegacyStaticDataMigrationResult> migrateFromLegacyStaticData(
    LegacyStaticDataImport legacy,
  );

  Future<void> close();
}
