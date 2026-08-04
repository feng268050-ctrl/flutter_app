import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

import 'process_library_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('trailingIconSizeFor matches HomeStatusBar scale', () {
    expect(
      WorkModeStatusBarDimens.trailingIconSizeFor(const Size(1280, 800)),
      32,
    );
    // reference logical ≈942×589 under Weston density match (DPR ~1.358).
    const logical = Size(942.4, 589.0);
    final sx = logical.width / 1280;
    final sy = logical.height / 800;
    expect(
      WorkModeStatusBarDimens.trailingIconSizeFor(logical),
      closeTo(32 * ((sx + sy) / 2), 0.01),
    );
  });

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets(
      'WorkModeStatusBar shows five equipment items and camera+time only',
      (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          appBar: WorkModeStatusBar(
            mode: WorkMode.quick,
            equipmentStatus: const WorkModeEquipmentStatus(
              gunSwitchOn: true,
              groundClampOn: true,
              keySwitchOn: false,
              gasFlowOn: true,
              eStopTriggered: false,
            ),
            cameraStatus: IpCameraUiStatus.connecting,
            clockNow: () => DateTime(2026, 7, 24, 14, 30),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Gun Switch'), findsOneWidget);
    expect(find.text('Safety Clamp'), findsOneWidget);
    expect(find.text('Key Switch'), findsOneWidget);
    expect(find.text('Gas Flow'), findsOneWidget);
    expect(find.text('E-Stop'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Home')).style?.fontSize,
      WorkModeStatusBarDimens.homeLabelFontSize,
    );
    expect(
      tester.widget<Text>(find.text('Gun Switch')).style?.fontSize,
      WorkModeStatusBarDimens.statusLabelFontSize,
    );
    expect(
      tester.widget<Text>(find.text('14:30')).style?.fontSize,
      WorkModeStatusBarDimens.chromeLabelFontSize,
    );
    expect(
        find.byKey(const ValueKey('work-mode-status-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
    expect(find.byKey(const ValueKey('cyber-status-bt')), findsNothing);

    // Side rails; camera+clock centered; label+icon groups with equal flexible
    // gaps (prefer full labels over a fixed 28 gap).
    expect(
      tester.getSize(find.byKey(const ValueKey('work-mode-status-back'))).width,
      WorkModeStatusBarDimens.sideRailWidth,
    );
    final gun = tester.getRect(
      find.byKey(const ValueKey('work-mode-gun-switch')),
    );
    final ground = tester.getRect(
      find.byKey(const ValueKey('work-mode-ground-clamp')),
    );
    final key = tester.getRect(
      find.byKey(const ValueKey('work-mode-key-switch')),
    );
    final gas = tester.getRect(
      find.byKey(const ValueKey('work-mode-gas-flow')),
    );
    final eStop = tester.getRect(
      find.byKey(const ValueKey('work-mode-e-stop')),
    );
    expect((gun.left + eStop.right) / 2, closeTo(640, 2));
    final camera = tester.getRect(
      find.byKey(const ValueKey('work-mode-status-camera')),
    );
    final clock = tester.getRect(find.text('14:30'));
    final trailingMid = (camera.left + clock.right) / 2;
    expect(
      trailingMid,
      closeTo(1280 - WorkModeStatusBarDimens.sideRailWidth / 2, 2),
    );
    // Full English labels stay visible at design width.
    expect(find.text('Gun Switch'), findsOneWidget);
    expect(find.text('Safety Clamp'), findsOneWidget);
    expect(find.text('Key Switch'), findsOneWidget);
    expect(find.text('Gas Flow'), findsOneWidget);
    expect(find.text('E-Stop'), findsOneWidget);
    final gaps = [
      ground.left - gun.right,
      key.left - ground.right,
      gas.left - key.right,
      eStop.left - gas.right,
    ];
    for (final gap in gaps) {
      expect(gap, closeTo(gaps.first, 0.5));
    }
    expect(gun.height, closeTo(WorkModeStatusBarDimens.primaryIconSize, 1));
  });

  testWidgets('WorkModeStatusBar swaps e-stop assets by latch', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          appBar: WorkModeStatusBar(
            mode: WorkMode.engineer,
            equipmentStatus:
                const WorkModeEquipmentStatus(eStopTriggered: true),
            cameraStatus: IpCameraUiStatus.connecting,
            clockNow: () => DateTime(2026, 7, 24, 9, 5),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('work-mode-status-bar-engineer')),
        findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('work-mode-status-bar-engineer')),
          )
          .color,
      Colors.transparent,
    );
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('QuickModePage keeps shared status bar without wifi/bt',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: wrapWithProcessLibrary(controller, const QuickModePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Gun Switch'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
    expect(find.byKey(const ValueKey('cyber-status-bt')), findsNothing);
  });

  testWidgets('EngineerModePage keeps shared status bar equipment strip',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: wrapWithProcessLibrary(controller, const EngineerModePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Safety Clamp'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
  });

  testWidgets('disabled Back uses gray label color', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          appBar: WorkModeStatusBar(
            mode: WorkMode.quick,
            backEnabled: false,
            cameraStatus: IpCameraUiStatus.connecting,
            clockNow: () => DateTime(2026, 7, 24, 14, 30),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Home'));
    expect(label.style?.color, WorkModeStatusBarDimens.backLabelDisabled);
  });

  testWidgets('clean processType keeps Back label white when enabled',
      (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          appBar: WorkModeStatusBar(
            mode: WorkMode.quick,
            processType: ProcessType.weldCleaning,
            cameraStatus: IpCameraUiStatus.connecting,
            clockNow: () => DateTime(2026, 7, 24, 14, 30),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    final label = tester.widget<Text>(find.text('Home'));
    expect(label.style?.color, Colors.white);
  });
}
