import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/advanced_settings_store.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_work_guard.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

void main() {
  BoardProfile testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "test",
  "platform": "linux",
  "capabilities": [],
  "helpers": {},
  "configs": {}
}
''');

  AppServices servicesWith(ModbusRtuClient modbus) => AppServices(
        boardProfile: testProfile(),
        sysInfo: StubSysInfo(),
        modbusClient: modbus,
      );

  group('LaserWorkGuard.processChangeBlock', () {
    test('null when laser enable/on and wire feed are off', () async {
      final modbus = _GuardModbus()
        ..control[LaserWorkGuard.laserEnableAttribute] = false
        ..status[LaserWorkGuard.laserOnAttribute] = false
        ..status[LaserWorkGuard.wireFeedingOnAttribute] = 0;
      expect(
        await LaserWorkGuard.processChangeBlock(servicesWith(modbus)),
        isNull,
      );
      expect(
        await LaserWorkGuard.isProcessChangeSafe(servicesWith(modbus)),
        isTrue,
      );
    });

    test('laserActive when laser enable is on', () async {
      final modbus = _GuardModbus()
        ..control[LaserWorkGuard.laserEnableAttribute] = true
        ..status[LaserWorkGuard.laserOnAttribute] = false
        ..status[LaserWorkGuard.wireFeedingOnAttribute] = false;
      expect(
        await LaserWorkGuard.processChangeBlock(servicesWith(modbus)),
        ProcessChangeBlockReason.laserActive,
      );
    });

    test('wireFeeding when wire feed feedback is on', () async {
      final modbus = _GuardModbus()
        ..control[LaserWorkGuard.laserEnableAttribute] = false
        ..status[LaserWorkGuard.laserOnAttribute] = false
        ..status[LaserWorkGuard.wireFeedingOnAttribute] = true;
      expect(
        await LaserWorkGuard.processChangeBlock(servicesWith(modbus)),
        ProcessChangeBlockReason.wireFeeding,
      );
    });

    test('statusUnavailable when a status attribute is missing', () async {
      final modbus = _GuardModbus()
        ..control[LaserWorkGuard.laserEnableAttribute] = false
        ..status[LaserWorkGuard.laserOnAttribute] = false;
      // wire_feeding_on absent → null
      expect(
        await LaserWorkGuard.processChangeBlock(servicesWith(modbus)),
        ProcessChangeBlockReason.statusUnavailable,
      );
    });

    test('statusUnavailable when group read throws', () async {
      final modbus = _GuardModbus(throwOnRead: true);
      expect(
        await LaserWorkGuard.processChangeBlock(servicesWith(modbus)),
        ProcessChangeBlockReason.statusUnavailable,
      );
    });
  });

  group('LaserWorkGuard.evaluateAndInterruptIfNeeded', () {
    test('does not clear laser when no active alarm episodes', () async {
      final modbus = _GuardModbus();
      final dir = await Directory.systemTemp.createTemp('laser-guard-');
      addTearDown(() => dir.delete(recursive: true));
      final store = AdvancedSettingsStore(
        preferencePath: '${dir.path}/advanced-settings.json',
      );
      store.warmRead();
      final dangerous = DangerousOperationsSettings(store);

      await LaserWorkGuard.evaluateAndInterruptIfNeeded(
        services: servicesWith(modbus),
        dangerous: dangerous,
      );

      expect(modbus.writes, isEmpty);
    });

    test('with host: force-off on interrupt even when Modbus would fail',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final modbus = _GuardModbus(writeOk: false);
      final dir = await Directory.systemTemp.createTemp('laser-guard-');
      addTearDown(() => dir.delete(recursive: true));
      final store = AdvancedSettingsStore(
        preferencePath: '${dir.path}/advanced-settings.json',
      );
      store.warmRead();
      final dangerous = DangerousOperationsSettings(store);
      final host = _FakeLaserHost();
      LaserWorkGuard.register(host);
      addTearDown(() => LaserWorkGuard.unregister(host));

      await LaserWorkGuard.evaluateAndInterruptIfNeeded(
        services: servicesWith(modbus),
        dangerous: dangerous,
        activeCodesOverride: const {'E011'},
      );

      expect(host.forceOffCalls, 1);
      // Host owns Modbus clear — no bare writeAttribute fallback.
      expect(modbus.writes, isEmpty);
    });

    test('without host: still writes laser_enable false on interrupt',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final modbus = _GuardModbus(writeOk: false);
      final dir = await Directory.systemTemp.createTemp('laser-guard-');
      addTearDown(() => dir.delete(recursive: true));
      final store = AdvancedSettingsStore(
        preferencePath: '${dir.path}/advanced-settings.json',
      );
      store.warmRead();
      final dangerous = DangerousOperationsSettings(store);
      expect(LaserWorkGuard.debugHost, isNull);

      await LaserWorkGuard.evaluateAndInterruptIfNeeded(
        services: servicesWith(modbus),
        dangerous: dangerous,
        activeCodesOverride: const {'E011'},
      );

      expect(modbus.writes, [(LaserWorkGuard.laserEnableAttribute, false)]);
    });
  });
}

final class _FakeLaserHost implements LaserWorkGuardHost {
  int forceOffCalls = 0;

  @override
  bool get isLaserEnableActive => true;

  @override
  Future<void> forceLaserOffForGuardedAlarm() async {
    forceOffCalls++;
  }
}

final class _GuardModbus extends ModbusRtuClient {
  _GuardModbus({this.throwOnRead = false, this.writeOk = true});

  final bool throwOnRead;
  final bool writeOk;
  final Map<String, Object?> control = {};
  final Map<String, Object?> status = {};
  final List<(String, Object?)> writes = [];

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<void> applyHealthWindowMode(String? mode) async {}

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    return switch (groupId) {
      'control' => Map<String, Object?>.from(control),
      'status' => Map<String, Object?>.from(status),
      _ => <String, Object?>{},
    };
  }

  @override
  Future<bool> writeAttribute(String id, Object? value) async {
    writes.add((id, value));
    return writeOk;
  }
}
