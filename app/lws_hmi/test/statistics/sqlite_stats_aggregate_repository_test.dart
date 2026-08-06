import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database database;
  late SqliteStatsAggregateRepository repository;

  setUp(() {
    database = sqlite3.openInMemory();
    repository = SqliteStatsAggregateRepository(database: database);
  });

  tearDown(() async {
    await repository.close();
  });

  test('settles automatic wire feed only and is idempotent by session id',
      () async {
    const event = WorkStopEvent(
      sessionId: 'session-1',
      modeType: 1,
      durationSeconds: 10,
      laserOnSeconds: 10,
      autoWireFeedSeconds: 4,
      autoWireFeedSpeedMmPerSecond: 12.5,
    );

    expect(await repository.recordWorkStop(event), isTrue);
    expect(await repository.recordWorkStop(event), isFalse);

    final stats = await repository.load();
    expect(stats.weldSecondsTotal, 10);
    expect(stats.weldSessionCountTotal, 1);
    expect(stats.laserOnSecondsTotal, 10);
    expect(stats.wireFeedLengthMmTotal, 50);
  });

  test('does not add wire feed when the work session has no automatic feed',
      () async {
    await repository.recordWorkStop(const WorkStopEvent(
      sessionId: 'session-without-auto-feed',
      modeType: 1,
      durationSeconds: 20,
      laserOnSeconds: 20,
    ));

    expect((await repository.load()).wireFeedLengthMmTotal, 0);
  });

  test('settles weld wire as sessionSeconds × wireFeedSpeed (lws-ui weldStop)',
      () async {
    final started = DateTime.utc(2026, 7, 30, 8);
    await repository.startWorkSession(WorkSessionStartEvent(
      sessionId: 'session-2',
      modeType: 1,
      // Flag is audit-only; weld modes always accumulate duration × speed.
      autoWireFeedEnabled: false,
      autoWireFeedSpeedMmPerSecond: 12.5,
      materialType: 2,
      startedAtMs: started.millisecondsSinceEpoch,
    ));

    expect(
      await repository.settleActiveWorkSession(
        endedAt: started.add(const Duration(seconds: 4)),
      ),
      isTrue,
    );
    expect(await repository.settleActiveWorkSession(), isFalse);

    final stats = await repository.load();
    expect(stats.laserEnableCountTotal, 1);
    expect(stats.weldSecondsTotal, 4);
    expect(stats.wireFeedLengthMmTotal, 50);
    expect(stats.lastSessionMaterialType, 2);
  });

  test('cut sessions do not add wire consumption', () async {
    final started = DateTime.utc(2026, 7, 30, 9);
    await repository.startWorkSession(WorkSessionStartEvent(
      sessionId: 'session-cut',
      modeType: 2,
      autoWireFeedEnabled: true,
      autoWireFeedSpeedMmPerSecond: 12.5,
      startedAtMs: started.millisecondsSinceEpoch,
    ));
    await repository.settleActiveWorkSession(
      endedAt: started.add(const Duration(seconds: 10)),
    );
    expect((await repository.load()).wireFeedLengthMmTotal, 0);
  });

  test('derives favorite material from settled session counts', () async {
    Future<void> settle(String id, int materialType) async {
      await repository.recordWorkStop(WorkStopEvent(
        sessionId: id,
        modeType: 1,
        durationSeconds: 1,
        laserOnSeconds: 1,
        materialType: materialType,
      ));
    }

    await settle('steel-1', 1);
    await settle('carbon-1', 2);
    var stats = await repository.load();
    // Counts tie, so the newest settled material wins deterministically.
    expect(stats.favoriteMaterialType, 2);
    expect(stats.stainlessSteelSessionCountTotal, 1);
    expect(stats.carbonSteelSessionCountTotal, 1);

    await settle('steel-2', 1);
    stats = await repository.load();
    expect(stats.favoriteMaterialType, 1);
    expect(stats.stainlessSteelSessionCountTotal, 2);
  });

  test('imports confirmed legacy fields once without unsafe unit guesses',
      () async {
    const legacy = LegacyStaticDataImport(
      source: 'lws-ui-static-data:test-export',
      weldSecondsTotal: 120,
      cutSecondsTotal: 60,
      cleanSecondsTotal: 30,
      jobRuntimeSecondsTotal: 300,
      favoriteMaterialType: 3,
    );

    expect(
      await repository.migrateFromLegacyStaticData(legacy),
      LegacyStaticDataMigrationResult.imported,
    );
    final stats = await repository.load();
    expect(stats.weldSecondsTotal, 120);
    expect(stats.cutSecondsTotal, 60);
    expect(stats.cleanSecondsTotal, 30);
    expect(stats.laserOnSecondsTotal, 210);
    expect(stats.jobRuntimeSecondsTotal, 300);
    expect(stats.wireFeedLengthMmTotal, 0);
    expect(stats.weekAnchorStartedAtMs, 0);
    expect(stats.favoriteMaterialType, 3);
    expect(stats.legacyStaticDataImportSource, legacy.source);
    expect(
      await repository.migrateFromLegacyStaticData(legacy),
      LegacyStaticDataMigrationResult.alreadyImported,
    );
  });

  test('will not overwrite live HMI aggregate with a late legacy import',
      () async {
    await repository.recordWorkStop(const WorkStopEvent(
      sessionId: 'hmi-session',
      modeType: 1,
      durationSeconds: 10,
      laserOnSeconds: 10,
    ));

    expect(
      await repository.migrateFromLegacyStaticData(
        const LegacyStaticDataImport(
          source: 'lws-ui-static-data:late-export',
          weldSecondsTotal: 500,
          cutSecondsTotal: 0,
          cleanSecondsTotal: 0,
          jobRuntimeSecondsTotal: 0,
        ),
      ),
      LegacyStaticDataMigrationResult.targetNotEmpty,
    );
    expect((await repository.load()).weldSecondsTotal, 10);
  });
}
