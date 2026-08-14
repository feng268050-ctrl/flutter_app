import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/monitor/presentation/widgets/monitor_gauges.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('More Status opens live machine status dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.continuousWelding,
              gasPressureKpa: 80,
              laserEnable: false,
              laserOn: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('quick-mode-more-status')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('live-machine-status-dialog')),
        findsOneWidget);
    expect(find.text('Live Machine Status'), findsOneWidget);
    expect(find.byKey(const ValueKey('live-machine-status-confirm')),
        findsOneWidget);
    // Alarm Welding-Gun temps under the gauges.
    expect(find.text('Motor'), findsWidgets);
    expect(find.text('Motor Driver'), findsOneWidget);
    expect(find.text('Protective Mirror'), findsOneWidget);
    expect(find.text('Collimator'), findsOneWidget);
    final gauges = tester
        .widgetList<CurrentArcGauge>(find.byType(CurrentArcGauge))
        .toList(growable: false);
    expect(gauges, hasLength(2));
    for (final gauge in gauges) {
      expect(gauge.visualStyle, GaugeVisualStyle.integratedRing);
      // Preserve More Status's existing 250px-high panel sizing:
      // 250 - 2 × 8px inset = 234px gauge side.
      expect(gauge.size, 234);
      expect(gauge.progressColor, const Color(0xFFD18846));
    }
    expect(gauges.first.max, 1500);
    expect(gauges.last.max, 100);
    // Must not route to Monitor.
    expect(find.text('Machine Status'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('live-machine-status-confirm')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('live-machine-status-dialog')), findsNothing);
  });
}
