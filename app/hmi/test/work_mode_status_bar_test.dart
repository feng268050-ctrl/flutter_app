import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';
import 'package:lws_hmi/features/process_library/presentation/engineer_mode_page.dart';
import 'package:lws_hmi/features/process_library/presentation/quick_mode_page.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setDesignSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  testWidgets('WorkModeStatusBar shows five equipment items and camera+time only',
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
    expect(find.byKey(const ValueKey('work-mode-status-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
    expect(find.byKey(const ValueKey('cyber-status-bt')), findsNothing);
  });

  testWidgets('WorkModeStatusBar swaps e-stop assets by latch', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: WorkModeStatusBar(
            mode: WorkMode.engineer,
            equipmentStatus: const WorkModeEquipmentStatus(eStopTriggered: true),
            cameraStatus: IpCameraUiStatus.connecting,
            clockNow: () => DateTime(2026, 7, 24, 9, 5),
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('work-mode-status-bar-engineer')), findsOneWidget);
    expect(find.text('09:05'), findsOneWidget);
  });

  testWidgets('QuickModePage is blank under shared status bar', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: QuickModePage()));
    await tester.pump();

    expect(find.byKey(const ValueKey('quick-mode-placeholder')), findsOneWidget);
    expect(find.text('Gun Switch'), findsOneWidget);
    expect(find.byKey(const ValueKey('cyber-status-wifi')), findsNothing);
  });

  testWidgets('EngineerModePage is blank under shared status bar', (tester) async {
    await setDesignSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: EngineerModePage()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('engineer-mode-placeholder')),
      findsOneWidget,
    );
    expect(find.text('Ground Clamp'), findsOneWidget);
  });
}
