import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/presentation/custom_home_statistics_panel.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';

void main() {
  group('weekOverWeekLaserPercent', () {
    StatsAggregate agg({
      required int total,
      required int weekAnchor,
      required int prevWeekAnchor,
    }) {
      return StatsAggregate(
        schemaVersion: 1,
        createdAtMs: 0,
        updatedAtMs: 0,
        lastResetAtMs: 0,
        lastSettledSessionId: null,
        weldSecondsTotal: 0,
        cutSecondsTotal: 0,
        cleanSecondsTotal: 0,
        laserOnSecondsTotal: total,
        jobRuntimeSecondsTotal: 0,
        wireFeedLengthMmTotal: 0,
        weldSessionCountTotal: 0,
        cutSessionCountTotal: 0,
        cleanSessionCountTotal: 0,
        laserEnableCountTotal: 0,
        lastSessionModeType: null,
        lastSessionDurationSeconds: null,
        lastSessionWireFeedSpeedMmPerSecond: null,
        lastSessionMaterialType: null,
        lastSessionEndedAtMs: null,
        weekAnchorStartedAtMs: 0,
        weekAnchorLaserOnSecondsTotal: weekAnchor,
        prevWeekAnchorStartedAtMs: 0,
        prevWeekAnchorLaserOnSecondsTotal: prevWeekAnchor,
        favoriteMaterialType: null,
        favoriteMaterialUpdatedAtMs: null,
        stainlessSteelSessionCountTotal: 0,
        carbonSteelSessionCountTotal: 0,
        galvanizedSheetSessionCountTotal: 0,
        aluminumAlloySessionCountTotal: 0,
        brassSessionCountTotal: 0,
        customMaterialSessionCountTotal: 0,
        legacyStaticDataImportedAtMs: null,
        legacyStaticDataImportSource: null,
      );
    }

    test('last week zero and this week positive → 100', () {
      expect(
        weekOverWeekLaserPercent(
          agg(total: 120, weekAnchor: 0, prevWeekAnchor: 0),
        ),
        100,
      );
    });

    test('both weeks zero → 0', () {
      expect(
        weekOverWeekLaserPercent(
          agg(total: 0, weekAnchor: 0, prevWeekAnchor: 0),
        ),
        0,
      );
    });

    test('equal weeks → 0', () {
      expect(
        weekOverWeekLaserPercent(
          agg(total: 200, weekAnchor: 100, prevWeekAnchor: 0),
        ),
        0,
      );
    });

    test('increase uses truncated growth percent', () {
      // this week 150, last week 100 → +50%
      expect(
        weekOverWeekLaserPercent(
          agg(total: 250, weekAnchor: 100, prevWeekAnchor: 0),
        ),
        50,
      );
    });

    test('decrease never returns a negative percent', () {
      // this week 50, last week 100 → 0 (not -50)
      expect(
        weekOverWeekLaserPercent(
          agg(total: 150, weekAnchor: 100, prevWeekAnchor: 0),
        ),
        0,
      );
    });

    test('null aggregate → 0', () {
      expect(weekOverWeekLaserPercent(null), 0);
    });
  });

  group('formatCustomHomeDurationSeconds', () {
    test('under one hour uses whole minutes', () {
      expect(
        formatCustomHomeDurationSeconds(0),
        (number: '0', unit: 'min'),
      );
      expect(
        formatCustomHomeDurationSeconds(59),
        (number: '0', unit: 'min'),
      );
      expect(
        formatCustomHomeDurationSeconds(60),
        (number: '1', unit: 'min'),
      );
      expect(
        formatCustomHomeDurationSeconds(59 * 60),
        (number: '59', unit: 'min'),
      );
    });

    test('one hour and above uses whole hours (75 min → 1h)', () {
      expect(
        formatCustomHomeDurationSeconds(3600),
        (number: '1', unit: 'h'),
      );
      expect(
        formatCustomHomeDurationSeconds(75 * 60),
        (number: '1', unit: 'h'),
      );
      expect(
        formatCustomHomeDurationSeconds(120 * 60),
        (number: '2', unit: 'h'),
      );
    });
  });

  test('wire consumption display uses mm under 1m and metres at/above', () {
    expect(
      LengthUnitConvert.formatWireConsumption(240),
      (number: '240', unit: 'mm'),
    );
    expect(
      LengthUnitConvert.formatWireConsumption(1298),
      (number: '1', unit: 'm'),
    );
    expect(
      LengthUnitConvert.formatWireConsumption(12980),
      (number: '12', unit: 'm'),
    );
  });

  test('persisted aggregate feeds Custom Home wire length (seconds × speed)',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('custom-home-stats');
    addTearDown(() => tempDir.delete(recursive: true));
    final repository = SqliteStatsAggregateRepository(
      dbPath: '${tempDir.path}/hmi-stats.db',
    );
    await repository.recordWorkStop(
      const WorkStopEvent(
        sessionId: 'custom-home-panel-test',
        modeType: 1,
        durationSeconds: 120,
        laserOnSeconds: 120,
        autoWireFeedSeconds: 120,
        autoWireFeedSpeedMmPerSecond: 2,
      ),
    );
    final stats = await repository.load();
    expect(stats.wireFeedLengthMmTotal, 240);
    expect(
      LengthUnitConvert.formatWireConsumption(stats.wireFeedLengthMmTotal),
      (number: '240', unit: 'mm'),
    );
    await repository.close();
  });
}
