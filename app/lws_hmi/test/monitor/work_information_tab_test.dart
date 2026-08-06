import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/application/work_information_display.dart';
import 'package:lws_hmi/features/monitor/presentation/tabs/work_information_tab.dart';
import 'package:lws_hmi/features/settings/application/common_settings_scope.dart';
import 'package:lws_hmi/features/settings/application/common_settings_store.dart';
import 'package:lws_hmi/features/settings/application/length_unit_convert.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  group('WorkInformationDisplay', () {
    test('ratios match lws-ui Home.newRatio truncation', () {
      final d = WorkInformationDisplay.fromAggregate(
        _agg(weld: 50, cut: 30, clean: 20, laserOn: 100),
      );
      expect(d.weldRatioPercent, 50);
      expect(d.cutRatioPercent, 30);
      expect(d.cleanRatioPercent, 20);
    });

    test('wire metric stays mm under 1 m and switches to integer metres', () {
      expect(
        LengthUnitConvert.formatWireConsumption(1298),
        (number: '1', unit: 'm'),
      );
      expect(
        LengthUnitConvert.formatWireConsumption(12980),
        (number: '12', unit: 'm'),
      );
      expect(
        LengthUnitConvert.formatWireConsumption(999),
        (number: '999', unit: 'mm'),
      );
    });

    test('wire imperial uses feet like WireConsumptionDisplayUtil', () {
      // 300 mm → 1 ft (25 mm/in × 12).
      final d = WorkInformationDisplay.fromAggregate(
        _agg(wireMm: 300),
        unitWire: CommonSettingsStore.unitImperial,
      );
      expect(d.wireNumber, '1');
      expect(d.wireUnit, 'ft');
    });

    test('laser-on and job runtime switch min→h at 1 hour like Home', () {
      final underHour = WorkInformationDisplay.fromAggregate(
        _agg(laserOn: 1800, jobRuntime: 125),
      );
      expect(underHour.laserOnNumber, '30');
      expect(underHour.laserOnUnit, 'min');
      expect(underHour.jobRuntimeNumber, '2');
      expect(underHour.jobRuntimeUnit, 'min');

      final overHour = WorkInformationDisplay.fromAggregate(
        _agg(
          laserOn: 7200,
          jobRuntime: 75 * 60,
          wireMm: 2500,
        ),
      );
      expect(overHour.laserOnNumber, '2');
      expect(overHour.laserOnUnit, 'h');
      expect(overHour.jobRuntimeNumber, '1');
      expect(overHour.jobRuntimeUnit, 'h');
      expect(overHour.wireNumber, '2');
      expect(overHour.wireUnit, 'm');
    });

    test('zero totals stay at 0%', () {
      final d = WorkInformationDisplay.fromAggregate(_agg());
      expect(d.weldRatioPercent, 0);
      expect(d.laserOnNumber, '0');
      expect(d.laserOnUnit, 'min');
      expect(d.jobRuntimeNumber, '0');
      expect(d.jobRuntimeUnit, 'min');
      expect(d.wireNumber, '0');
      expect(d.wireUnit, 'mm');
    });
  });

  testWidgets('WorkInformationTab binds aggregate into gauges and cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final repo = _FakeStatsRepository(
      _agg(
        weld: 60,
        cut: 30,
        clean: 10,
        laserOn: 3600,
        jobRuntime: 180,
        wireMm: 5000,
      ),
    );
    final settings = CommonSettingsStore(
      preferencePath: '/tmp/lws-hmi-work-info-test-settings.json',
    )..warmRead();

    await tester.pumpWidget(
      CommonSettingsScope(
        store: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: WorkInformationTab(
              repository: repo,
              pollInterval: Duration.zero,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('60%'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('1'), findsWidgets); // laser hours
    expect(find.text('5'), findsWidgets); // wire metres
    expect(find.text('3'), findsWidgets); // job minutes
    expect(find.text('h'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
  });
}

StatsAggregate _agg({
  int weld = 0,
  int cut = 0,
  int clean = 0,
  int laserOn = 0,
  int jobRuntime = 0,
  int wireMm = 0,
}) {
  return StatsAggregate(
    schemaVersion: 1,
    createdAtMs: 0,
    updatedAtMs: 0,
    lastResetAtMs: 0,
    lastSettledSessionId: null,
    weldSecondsTotal: weld,
    cutSecondsTotal: cut,
    cleanSecondsTotal: clean,
    laserOnSecondsTotal: laserOn,
    jobRuntimeSecondsTotal: jobRuntime,
    wireFeedLengthMmTotal: wireMm,
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
    weekAnchorLaserOnSecondsTotal: 0,
    prevWeekAnchorStartedAtMs: 0,
    prevWeekAnchorLaserOnSecondsTotal: 0,
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

final class _FakeStatsRepository implements StatsAggregateRepository {
  _FakeStatsRepository(this.aggregate);

  StatsAggregate aggregate;

  @override
  Future<void> open() async {}

  @override
  Future<void> close() async {}

  @override
  Future<StatsAggregate> load() async => aggregate;

  @override
  Future<void> refreshWeekAnchors(DateTime now) async {}

  @override
  Future<void> addJobRuntimeSeconds(int seconds) =>
      throw UnimplementedError();

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
  Future<bool> settleActiveWorkSession({DateTime? endedAt}) =>
      throw UnimplementedError();

  @override
  Future<void> startWorkSession(WorkSessionStartEvent event) =>
      throw UnimplementedError();
}
