import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/statistics/application/job_runtime_statistics_recorder.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';

void main() {
  test('adds only measured foreground runtime', () async {
    var current = DateTime.utc(2026, 7, 30, 8);
    final repository = _FakeStatsRepository();
    final recorder = JobRuntimeStatisticsRecorder(
      repository: repository,
      now: () => current,
    );

    recorder.resume();
    current = current.add(const Duration(seconds: 12));
    await recorder.flush();
    await recorder.pause();

    expect(repository.runtimeSeconds, 12);
  });

  test('drops an untrusted long suspended interval', () async {
    var current = DateTime.utc(2026, 7, 30, 8);
    final repository = _FakeStatsRepository();
    final recorder = JobRuntimeStatisticsRecorder(
      repository: repository,
      now: () => current,
    );

    recorder.resume();
    current = current.add(const Duration(minutes: 3));
    await recorder.flush();

    expect(repository.runtimeSeconds, 0);
  });
}

final class _FakeStatsRepository implements StatsAggregateRepository {
  int runtimeSeconds = 0;

  @override
  Future<void> addJobRuntimeSeconds(int seconds) async =>
      runtimeSeconds += seconds;

  @override
  Future<void> close() async {}

  @override
  Future<StatsAggregate> load() => throw UnimplementedError();

  @override
  Future<LegacyStaticDataMigrationResult> migrateFromLegacyStaticData(
    LegacyStaticDataImport legacy,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> recordLaserEnable() => throw UnimplementedError();

  @override
  Future<bool> recordWorkStop(WorkStopEvent event) =>
      throw UnimplementedError();

  @override
  Future<void> refreshWeekAnchors(DateTime now) => throw UnimplementedError();

  @override
  Future<bool> settleActiveWorkSession({DateTime? endedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> startWorkSession(WorkSessionStartEvent event) =>
      throw UnimplementedError();

  @override
  Future<void> open() async {}
}
