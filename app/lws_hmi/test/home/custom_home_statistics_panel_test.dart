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
    expect(find.text('Total Wire Consumption'), findsOneWidget);
    expect(find.text('Total Laser-on Time'), findsOneWidget);
    expect(find.text('Job Runtime'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await repository.close();
  });
}
