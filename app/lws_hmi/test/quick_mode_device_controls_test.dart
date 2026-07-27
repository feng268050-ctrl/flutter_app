import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_tokens.dart';
import 'package:lws_hmi/features/process_mode/presentation/process_mode_toast.dart';
import 'package:lws_hmi/features/process_mode/presentation/quick_mode_device_controls.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(ProcessModeToast.resetForTest);

  AppServices servicesWith(ModbusRtuClient modbus) {
    return AppServices(
      boardProfile: BoardProfile.fromJsonString('''
{
  "schema_version": 1,
  "board_id": "test",
  "display_name": "Test",
  "bindings": {"sys_info": "stub"}
}
'''),
      sysInfo: StubSysInfo(),
      modbusClient: modbus,
    );
  }

  Future<void> pumpControls(
    WidgetTester tester, {
    required ProcessType processType,
    DeviceControlController? controller,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final c = controller ?? DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ProcessModeToastLayer(
          child: Scaffold(
            body: QuickModeDeviceControls(
              controller: c,
              processType: processType,
              laserPreflight: () => null,
              onEnableConfirmed: () async {},
              onDisable: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('continuous weld Feed shows hold-3s hint', (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);
    expect(
      find.byKey(const ValueKey('device-control-feed-hold-hint')),
      findsOneWidget,
    );
    expect(find.text('Hold 3s to keep on'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
  });

  testWidgets('pins left/right groups to screen corners', (tester) async {
    await pumpControls(tester, processType: ProcessType.continuousWelding);

    final gas = tester.getRect(
      find.byKey(const ValueKey('device-control-manual-gas')),
    );
    final feed = tester.getRect(
      find.byKey(const ValueKey('device-control-feed')),
    );
    const scale = 0.625; // 800×500 logical viewport on the 1280×800 test view.
    expect(
      gas.left,
      closeTo(ProcessModeDimens.quickSideButtonInset * scale, 1),
    );
    expect(
      gas.width,
      closeTo(ProcessModeDimens.quickSideButtonWidth * scale, 1),
    );
    expect(
      feed.right,
      closeTo(1280 - ProcessModeDimens.quickSideButtonInset * scale, 1),
    );
  });

  testWidgets('shows Auto Wire / Feed / Retract for cleaning without greying',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.weldCleaning);

    expect(find.byKey(const ValueKey('device-control-manual-gas')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-auto-wire-feed')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-feed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-control-retract')),
      findsOneWidget,
    );
    expect(find.text('Auto Wire Feed'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
  });

  testWidgets('toasts wire unavailable when tapping Feed in cleaning mode',
      (tester) async {
    await pumpControls(tester, processType: ProcessType.weldCleaning);
    final center =
        tester.getCenter(find.byKey(const ValueKey('device-control-feed')));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.text('Wire feed unavailable in this mode'), findsOneWidget);
  });

  testWidgets('toasts End of work first when tapping Feed while laser open',
      (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..laserEnable = true;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );
    final center =
        tester.getCenter(find.byKey(const ValueKey('device-control-feed')));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.text('End of work first'), findsOneWidget);
  });

  testWidgets('keeps side groups visible while laser is open', (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..laserEnable = true;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );

    expect(
      find.byKey(const ValueKey('device-control-manual-gas')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('device-control-feed')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick-mode-laser-enable')),
      findsOneWidget,
    );
  });

  testWidgets('toasts End of work first when tapping gas while laser open',
      (tester) async {
    final controller = DeviceControlController(servicesWith(_IdleModbus()))
      ..keySwitchOn = true
      ..laserEnable = true;
    await pumpControls(
      tester,
      processType: ProcessType.continuousWelding,
      controller: controller,
    );

    await tester.tap(find.byKey(const ValueKey('device-control-manual-gas')));
    await tester.pump();
    expect(find.text('End of work first'), findsOneWidget);
  });

  test('side highlight uses transparent-mid-transparent stops', () {
    final g = ProcessModeTokens.sideOperationHighlight(
      ProcessType.continuousWelding,
    );
    expect(g.colors.length, 3);
    expect(g.colors.first.alpha, 0);
    expect(g.colors[1].alpha, greaterThan(0));
    expect(g.colors.last.alpha, 0);
  });
}

final class _IdleModbus extends ModbusRtuClient {
  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async => true;

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
