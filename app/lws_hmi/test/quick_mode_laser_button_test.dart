import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_button.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_laser_dashboard.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_parameter_preview.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

final class _CountingClick implements CyberClickSound {
  int calls = 0;

  @override
  Future<void> playClick() async {
    calls++;
  }
}

void main() {
  tearDown(() => CyberClickSoundRegistry.register(null));

  testWidgets('laser trapezoid requires filled hold and release to enable',
      (tester) async {
    var enabled = 0;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
        ProcessModeDimens.quickLaserButtonWidth * 0.625,
        ProcessModeDimens.quickLaserButtonHeight * 0.625,
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
    final clicks = _CountingClick();
    CyberClickSoundRegistry.register(clicks);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    expect(find.text('End Of Work'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
    );
    await tester.pump();
    expect(disabled, 1);
    expect(clicks.calls, 1);
  });

  testWidgets('Laser Enable plays click after a completed hold', (tester) async {
    final clicks = _CountingClick();
    CyberClickSoundRegistry.register(clicks);
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: QuickModeLaserButton(
              processType: ProcessType.continuousWelding,
              laserOpen: false,
              busy: false,
              preflight: () => null,
              onEnableConfirmed: () async {},
              onDisable: () async {},
              onBlocked: (_) {},
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('quick-mode-laser-enable'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 310));
    await gesture.up();
    await tester.pump();

    expect(clicks.calls, 1);
  });

  testWidgets('More Parameters plays click when enabled', (tester) async {
    final clicks = _CountingClick();
    CyberClickSoundRegistry.register(clicks);
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickModeMoreParametersButton(
            enabled: true,
            onPressed: () => presses++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('quick-mode-more-parameters')));
    await tester.pump();

    expect(presses, 1);
    expect(clicks.calls, 1);
  });

  testWidgets('transparent laser chrome does not steal More Status taps',
      (tester) async {
    var moreTaps = 0;
    // Force 1280×800 logical (design canvas). Default test view is 800×600
    // where More Status and the laser graphic do not overlap.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(height: 70, color: Colors.black),
          ),
          body: Stack(
            children: [
              Center(
                child: QuickModeLaserDashboard(
                  processType: ProcessType.continuousWelding,
                  gasPressureKpa: 80,
                  laserEnable: false,
                  laserOn: false,
                  onMoreStatus: () => moreTaps++,
                ),
              ),
              // Same overlay order as QuickModePage device controls.
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: QuickModeLaserButton(
                    processType: ProcessType.continuousWelding,
                    laserOpen: false,
                    busy: false,
                    preflight: () => null,
                    onEnableConfirmed: () async {},
                    onDisable: () async {},
                    onBlocked: (_) {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final more = find.byKey(const ValueKey('quick-mode-more-status'));
    final laser = find.byKey(const ValueKey('quick-mode-laser-enable'));
    expect(
      tester.getRect(more).overlaps(tester.getRect(laser)),
      isTrue,
      reason: 'test must cover the real status-bar overlap band',
    );

    await tester.tap(more);
    await tester.pump();
    expect(moreTaps, 1);
  });
}
