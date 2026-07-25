import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows gas pressure and more status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.continuousWelding,
              gasPressureKpa: 101,
              laserEnable: false,
              laserOn: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('quick-mode-laser-dashboard')),
        findsOneWidget);
    expect(find.text('101'), findsOneWidget);
    expect(find.text('Gas Pressure'), findsOneWidget);
    expect(find.text('kPa'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('quick-mode-more-status')), findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('quick-mode-laser-dashboard')),
      ),
      const Size(356.25, 377.1875),
    );
    expect(
      ProcessModeDimens.dashboardScaleFor(const Size(800, 600)),
      0.625,
    );

    // Digit centered on the pressure circle.
    final dash = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-laser-dashboard')),
    );
    final value = tester.getCenter(
      find.byKey(const ValueKey('quick-mode-gas-pressure')),
    );
    expect(value.dx, closeTo(dash.dx, 1));
    expect(value.dy, closeTo(dash.dy, 2));

    final scale = ProcessModeDimens.dashboardScaleFor(const Size(800, 600));

    // Gas Pressure restored to original Column top slot (contentTop from panel).
    final titleTop = tester.getTopLeft(find.text('Gas Pressure')).dy;
    final expectedTitleTop = dash.dy - (372 * scale) / 2 + (50 * scale);
    expect(titleTop, closeTo(expectedTitleTop, 4));

    // More Status: longer frost pill (minWidth 240×scale), still centered.
    final more = tester.getSize(
      find.byKey(const ValueKey('quick-mode-more-status')),
    );
    expect(more.width, greaterThanOrEqualTo(250 * scale - 1));
    expect(
      tester.getCenter(find.byKey(const ValueKey('quick-mode-more-status'))).dx,
      closeTo(dash.dx, 1),
    );
  });

  testWidgets('laserOn / laserOff drive climb and fall without crash',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.continuousWelding,
              gasPressureKpa: 42,
              laserEnable: true,
              laserOn: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.continuousWelding,
              gasPressureKpa: 42,
              laserEnable: true,
              laserOn: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('42'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.continuousWelding,
              gasPressureKpa: 42,
              laserEnable: true,
              laserOn: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const ValueKey('quick-mode-laser-dashboard')),
        findsOneWidget);
    // Finish pending timers.
    await tester.pump(const Duration(milliseconds: 5000));
  });

  testWidgets('cleaning palette still renders center panel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserDashboard(
              processType: ProcessType.weldCleaning,
              gasPressureKpa: 80,
              laserEnable: true,
              laserOn: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('80'), findsOneWidget);
  });
}
