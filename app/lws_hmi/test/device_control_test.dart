import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_library/domain/process_library_models.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_ids.dart';
import 'package:lws_hmi/features/process_mode/presentation/device_control_bar.dart';
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

  test('DeviceControlController applyChanges updates laser/gas', () {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()));
    controller.applyChanges(const [
      ModbusAttributeChange(id: DeviceControlIds.laserEnable, value: true),
      ModbusAttributeChange(id: DeviceControlIds.manualGas, value: true),
      ModbusAttributeChange(id: DeviceControlIds.keySwitchOn, value: true),
    ]);
    expect(controller.laserEnable, isTrue);
    expect(controller.manualGas, isTrue);
    expect(controller.keySwitchOn, isTrue);
  });

  test('setManualGas clears laser first when enabling', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus));
    controller.laserEnable = true;
    controller.keySwitchOn = true;

    final err = await controller.setManualGas(true);
    expect(err, isNull);
    expect(modbus.writes.map((e) => e.$1).toList(), [
      DeviceControlIds.wireWork,
      DeviceControlIds.laserEnable,
      DeviceControlIds.manualGas,
    ]);
    expect(modbus.writes[0].$2, false);
    expect(modbus.writes[1].$2, false);
    expect(modbus.writes[2].$2, true);
    expect(controller.laserEnable, isFalse);
    expect(controller.manualGas, isTrue);
  });

  test('enableLaser blocked by e-stop without write', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus));
    controller.emergencyStop = true;
    controller.keySwitchOn = true;

    final err = await controller.enableLaser();
    expect(err, LaserEnableBlockReason.emergencyStop);
    expect(modbus.writes, isEmpty);
  });

  test('enable and disable laser clear wire work before control write',
      () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus));
    controller.keySwitchOn = true;

    expect(await controller.enableLaser(), isNull);
    expect(await controller.disableLaser(), isNull);
    expect(modbus.writes, [
      (DeviceControlIds.wireWork, false),
      (DeviceControlIds.laserEnable, true),
      (DeviceControlIds.wireWork, false),
      (DeviceControlIds.laserEnable, false),
    ]);
  });

  test('laser preflight blocks manual gas before hold', () {
    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()));
    controller.keySwitchOn = true;
    controller.manualGas = true;

    expect(
      controller.preflightLaserEnable(),
      LaserEnableBlockReason.manualGasOn,
    );
  });

  test('wire controls use direction, work, and auto-feed bits', () async {
    final modbus = _RecordingModbus();
    final controller = DeviceControlController(servicesWith(modbus));

    expect(await controller.setAutoWireFeed(false), isNull);
    expect(await controller.startWire(retract: true), isNull);
    expect(await controller.stopWire(), isNull);
    expect(modbus.writes, [
      (DeviceControlIds.wireWork, false),
      (DeviceControlIds.wireManualMode, false),
      (DeviceControlIds.laserEnable, false),
      (DeviceControlIds.wireDirection, true),
      (DeviceControlIds.wireWork, true),
      (DeviceControlIds.wireDirection, false),
      (DeviceControlIds.wireWork, false),
    ]);
    expect(controller.autoWireFeed, isFalse);
    expect(controller.wireWork, isFalse);
    expect(controller.wireRetracting, isFalse);
  });

  testWidgets('DeviceControlBar shows gas, laser, and wire stub',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()));
    controller.keySwitchOn = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceControlBar(
            controller: controller,
            processType: ProcessType.continuousWelding,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('device-control-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-manual-gas')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('device-control-laser')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('device-control-wire-stub')),
      findsOneWidget,
    );
  });

  testWidgets('DeviceControlBar hides wire stub for cleaning', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller =
        DeviceControlController(servicesWith(_RecordingModbus()));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceControlBar(
            controller: controller,
            processType: ProcessType.weldCleaning,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('device-control-wire-stub')),
      findsNothing,
    );
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
