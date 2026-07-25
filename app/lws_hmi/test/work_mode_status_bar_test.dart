import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.text('Ground Clamp'), findsOneWidget);
    expect(find.text('Key Switch'), findsOneWidget);
    expect(find.text('Gas Flow'), findsOneWidget);
    expect(find.text('E-Stop'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('work-mode-status-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
    expect(find.byKey(const ValueKey('cyber-status-bt')), findsNothing);

    // lws-ui geometry: fixed 160dp side rails keep the equipment group on the
    // screen center; trailing content is end-aligned with 16dp padding.
    expect(
      tester.getSize(find.byKey(const ValueKey('work-mode-status-back'))).width,
      WorkModeStatusBarDimens.sideRailWidth,
    );
    final first = tester.getRect(
      find.byKey(const ValueKey('work-mode-gun-switch')),
    );
    final last = tester.getRect(find.byKey(const ValueKey('work-mode-e-stop')));
    expect((first.left + last.right) / 2, closeTo(640, 1));
    expect(tester.getTopRight(find.text('14:30')).dx, closeTo(1264, 1));
  });

  testWidgets('WorkModeStatusBar swaps e-stop assets by latch', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
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
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('QuickModePage keeps shared status bar without wifi/bt',
      (tester) async {
    await setDesignSurface(tester);
    final controller = await createEmptyProcessLibraryController(tester);
    await tester.pumpWidget(
      MaterialApp(
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
        home: wrapWithProcessLibrary(controller, const EngineerModePage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ground Clamp'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
  });

  testWidgets('disabled Back uses gray label color', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
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

    final label = tester.widget<Text>(find.text('Back'));
    expect(label.style?.color, WorkModeStatusBarDimens.backLabelDisabled);
  });

  testWidgets('clean processType keeps Back label white when enabled',
      (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
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

    final label = tester.widget<Text>(find.text('Back'));
    expect(label.style?.color, Colors.white);
  });
}
