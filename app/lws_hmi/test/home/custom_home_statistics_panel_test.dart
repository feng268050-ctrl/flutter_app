import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/home/application/custom_home_layout_store.dart';
import 'package:lws_hmi/features/home/domain/custom_home_layout.dart';
import 'package:lws_hmi/features/home/presentation/custom_home_statistics_panel.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
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

  testWidgets('renders the first four persisted Custom Home metrics',
      (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('custom-home-stats');
    addTearDown(() => tempDir.delete(recursive: true));
    final layoutStore = CustomHomeLayoutStore(
      preferencePath: '${tempDir.path}/custom-home-layout.json',
    );
    await layoutStore.saveOrder(const [
      CustomHomeMetric.cutRatio,
      CustomHomeMetric.wireConsumption,
      CustomHomeMetric.laserOnDuration,
      CustomHomeMetric.jobRuntime,
      CustomHomeMetric.weldRatio,
      CustomHomeMetric.cleanRatio,
      CustomHomeMetric.weekOverWeekLaser,
      CustomHomeMetric.favoriteMaterial,
    ]);
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
    await repository.addJobRuntimeSeconds(180);

    await tester.pumpWidget(
      CommonSettingsScope(
        store: CommonSettingsStore(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 1224,
                height: 124,
                child: CustomHomeStatisticsPanel(
                  cardWidth: 200,
                  cardHeight: 124,
                  cardGap: 20,
                  layoutStore: layoutStore,
                  repository: repository,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-stat-cutRatio')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-stat-wireConsumption')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-stat-laserOnDuration')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-stat-jobRuntime')), findsOneWidget);
    expect(find.text('Cutting Ratio'), findsOneWidget);
    expect(find.text('Total wire consumption'), findsOneWidget);
    expect(find.text('Total laser-on time'), findsOneWidget);
    expect(find.text('Job runtime'), findsOneWidget);
    // Wire length 240 mm; laser 120s → 2 min; job 180s → 3 min.
    expect(find.text('240'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('min'), findsNWidgets(2));

    await repository.close();
  });
}
