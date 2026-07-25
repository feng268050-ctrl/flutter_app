import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/engineer_device_panel.dart';
import 'package:lws_hmi/features/process_mode/presentation/manual_wire_gesture.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  ProcessPreset presetFor(ProcessType type) => ProcessPreset(
        uuid: 'p-$type',
        name: 'P',
        kind: ProcessPresetKind.engineerPreset,
        source: 'test',
        isBuiltin: true,
        processType: type,
        materialType: MaterialType.stainlessSteel,
        thickness: 1,
        gear: 1,
        parameters: ProcessParameters({}),
        createdAtMs: 1,
        updatedAtMs: 1,
      );

  testWidgets('continuous weld enables Auto Wire / Feed / Retract',
      (tester) async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus))
      ..keySwitchOn = true
      ..autoWireFeed = false;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: EngineerDevicePanel(
              controller: controller,
              processType: ProcessType.continuousWelding,
              preset: presetFor(ProcessType.continuousWelding),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('engineer-panel-auto-wire')));
    await tester.pump();
    expect(controller.autoWireFeed, isTrue);
    expect(
      modbus.writes.any((e) => e.$1 == DeviceControlIds.wireManualMode),
      isTrue,
    );

    expect(find.byKey(const ValueKey('engineer-panel-feed')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('engineer-panel-retract')), findsOneWidget);
  });

  testWidgets('spot welding keeps wire controls disabled', (tester) async {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()))
          ..keySwitchOn = true
          ..autoWireFeed = false;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 700,
            child: EngineerDevicePanel(
              controller: controller,
              processType: ProcessType.spotWelding,
              preset: presetFor(ProcessType.spotWelding),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('engineer-panel-auto-wire')));
    await tester.pump();
    expect(controller.autoWireFeed, isFalse);
  });

  test('ManualWireGesture short press pulses wire work', () {
    fakeAsync((async) {
      final modbus = _RecordingModbus();
      final controller = DeviceControlController(servicesWith(modbus))
        ..keySwitchOn = true;
      final gesture = ManualWireGesture(
        controller: controller,
        retract: false,
        isEnabled: () => true,
        isActive: () => false,
        onMessage: (_) {},
        onVisualChanged: () {},
      );

      gesture.pointerDown();
      gesture.pointerUp();
      async.flushMicrotasks();
      async.elapse(DeviceControlTiming.wirePulseDuration);
      async.flushMicrotasks();

      final wireWrites = modbus.writes
          .where((e) => e.$1 == DeviceControlIds.wireWork)
          .map((e) => e.$2)
          .toList();
      expect(wireWrites, containsAllInOrder([true, false]));
      gesture.dispose();
    });
  });
}

final class _RecordingModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String group) async => {};

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}
