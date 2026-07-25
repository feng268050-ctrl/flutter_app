import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('More Status opens live machine status dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
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
    // Must not route to Monitor.
    expect(find.text('Machine Status'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('live-machine-status-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('live-machine-status-dialog')),
        findsNothing);
  });
}
