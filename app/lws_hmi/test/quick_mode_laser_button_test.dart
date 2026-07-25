import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_button.dart';

void main() {
  testWidgets('laser trapezoid requires filled hold and release to enable',
      (tester) async {
    var enabled = 0;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserButton(
              processType: ProcessType.continuousWelding,
              laserOpen: false,
              busy: false,
              preflight: () => null,
              onEnableConfirmed: () async => enabled++,
              onDisable: () async {},
              onBlocked: (_) {},
            ),
          ),
        ),
      ),
    );

    final finder = find.byKey(const ValueKey('quick-mode-laser-enable'));
    expect(
      tester.getSize(finder),
      const Size(
        ProcessModeDimens.quickLaserButtonWidth,
        ProcessModeDimens.quickLaserButtonHeight,
      ),
    );

    await tester.tap(finder);
    await tester.pump();
    expect(enabled, 0);

    final gesture = await tester.startGesture(tester.getCenter(finder));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 310));
    expect(enabled, 0);
    await gesture.up();
    await tester.pump();
    expect(enabled, 1);
  });

  testWidgets('open laser uses immediate End of work tap', (tester) async {
    var disabled = 0;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickModeLaserButton(
              processType: ProcessType.weldCleaning,
              laserOpen: true,
              busy: false,
              preflight: () => null,
              onEnableConfirmed: () async {},
              onDisable: () async => disabled++,
              onBlocked: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('End of work'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
    );
    await tester.pump();
    expect(disabled, 1);
  });
}
