import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/application/cnc_session_controller.dart';
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

  test('enter writes Modbus CNC process type 4', () async {
    final modbus = _CncModbus();
    final controller = CncSessionController(servicesWith(modbus));
    addTearDown(controller.dispose);

    await controller.enter();

    expect(modbus.writes, [('control.process_type', 4)]);
    expect(controller.active, isTrue);
    expect(controller.linkStatus, CncLinkStatus.connecting);
    expect(controller.runningOverlay, isFalse);
  });

  test('connected bit opens running overlay', () async {
    final modbus = _CncModbus();
    final controller = CncSessionController(servicesWith(modbus));
    addTearDown(controller.dispose);

    await controller.enter();
    controller.applyConnectedForTest(true);

    expect(controller.linkStatus, CncLinkStatus.success);
    expect(controller.runningOverlay, isTrue);
    expect(controller.blocksNavigation, isTrue);
    expect(controller.lastMessage, 'CNC connected');
  });

  test('timeout marks connection failed without overlay', () {
    FakeAsync().run((async) {
      final modbus = _CncModbus();
      final controller = CncSessionController(servicesWith(modbus));
      addTearDown(controller.dispose);

      controller.enter();
      async.flushMicrotasks();
      async.elapse(CncSessionController.connectionTimeout);

      expect(controller.linkStatus, CncLinkStatus.failed);
      expect(controller.runningOverlay, isFalse);
      expect(controller.lastMessage, 'CNC connection failed');
    });
  });

  test('exit writes continuous welding and dismisses overlay', () async {
    final modbus = _CncModbus();
    final controller = CncSessionController(servicesWith(modbus));
    addTearDown(controller.dispose);

    await controller.enter();
    controller.applyConnectedForTest(true);
    final ok = await controller.exitToGuide(writeContinuous: true);

    expect(ok, isTrue);
    expect(modbus.writes, [
      ('control.process_type', 4),
      ('control.process_type', 0),
    ]);
    expect(controller.runningOverlay, isFalse);
    expect(controller.sessionDismissed, isTrue);
    expect(controller.linkStatus, CncLinkStatus.failed);
  });

  test('sessionDismissed ignores reconnect until disconnect', () async {
    final modbus = _CncModbus();
    final controller = CncSessionController(servicesWith(modbus));
    addTearDown(controller.dispose);

    await controller.enter();
    controller.applyConnectedForTest(true);
    await controller.exitToGuide(writeContinuous: true);

    controller.applyConnectedForTest(true);
    expect(controller.runningOverlay, isFalse);

    controller.applyConnectedForTest(false);
    controller.applyConnectedForTest(true);
    expect(controller.runningOverlay, isTrue);
  });

  test('disconnect while overlay returns to guide without process write',
      () async {
    final modbus = _CncModbus();
    final controller = CncSessionController(servicesWith(modbus));
    addTearDown(controller.dispose);

    await controller.enter();
    controller.applyConnectedForTest(true);
    modbus.writes.clear();
    controller.applyConnectedForTest(false);

    // Allow async exitToGuide to finish.
    await Future<void>.delayed(Duration.zero);

    expect(controller.runningOverlay, isFalse);
    expect(modbus.writes, isEmpty);
  });
}

final class _CncModbus extends ModbusRtuClient {
  final writes = <(String, Object?)>[];
  final _controller = StreamController<List<ModbusAttributeChange>>.broadcast();
  bool cncConnected = false;

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) => body();

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return true;
  }

  @override
  Future<Map<String, Object?>> readGroup(String group) async {
    if (group == 'status') {
      return {
        CncSessionController.cncConnectedId: cncConnected,
      };
    }
    return {};
  }

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      _controller.stream;
}
