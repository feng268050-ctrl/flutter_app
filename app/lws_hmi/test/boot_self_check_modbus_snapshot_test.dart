import 'dart:async';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_evaluator.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_live_cache_seed.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_modbus_snapshot.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

class _GroupModbus extends ModbusRtuClient {
  _GroupModbus({
    this.status = const {},
    this.data = const {},
    this.failStatus = false,
    this.failData = false,
    this.openResult = true,
  }) : super();

  Map<String, Object?> status;
  Map<String, Object?> data;
  final bool failStatus;
  final bool failData;
  bool openResult;
  final List<String> readGroups = <String>[];
  int openCalls = 0;
  int exclusiveSessionCalls = 0;

  @override
  Future<bool> open() async {
    openCalls++;
    return openResult;
  }

  @override
  Future<T> exclusiveSession<T>(Future<T> Function() body) async {
    exclusiveSessionCalls++;
    return body();
  }

  @override
  Future<Map<String, Object?>> readGroup(String groupId) async {
    readGroups.add(groupId);
    if (groupId == 'status') {
      if (failStatus) {
        throw const HalIoException('modbus group read failed');
      }
      return Map<String, Object?>.of(status);
    }
    if (groupId == 'data') {
      if (failData) {
        throw const HalIoException('modbus group read failed');
      }
      return Map<String, Object?>.of(data);
    }
    throw HalNotFoundException('modbus group not found: $groupId');
  }

  @override
  Future<Object?> readAttribute(String id) async {
    fail('readAttribute should not be used by boot self-check snapshot');
  }
}

Map<String, Object?> _readyStatus({int deviceType = 1}) => {
      BootSelfCheckModbusIds.deviceType: deviceType,
      BootSelfCheckModbusIds.laserComm: false,
      BootSelfCheckModbusIds.gunComm: false,
      BootSelfCheckModbusIds.wireFeederComm: false,
      MonitorModbusIds.motorOverTemp: false,
      MonitorModbusIds.driverOverTemp: false,
      MonitorModbusIds.protectiveMirrorOverTemp: false,
      MonitorModbusIds.collimatorOverTemp: false,
    };

Map<String, Object?> get _readyData => {
      MonitorModbusIds.motorTemp: 25,
      MonitorModbusIds.motorDriverTemp: 26,
      MonitorModbusIds.protectiveMirrorTemp: 27,
      MonitorModbusIds.collimatorTemp: 28,
    };

void main() {
  tearDown(BootSelfCheckLiveCacheSeed.resetForTest);

  test('reads status+data groups and offers live-cache seed', () async {
    final modbus = _GroupModbus(
      status: _readyStatus(),
      data: _readyData,
    );

    final snap = await BootSelfCheckModbusSnapshotReader.read(modbus);
    expect(modbus.exclusiveSessionCalls, 1);
    expect(modbus.readGroups, ['status', 'data']);
    expect(snap.modbusAvailable, isTrue);
    expect(snap.controllerReady, isTrue);
    expect(snap.isUsable, isTrue);
    expect(snap[BootSelfCheckModbusIds.deviceType], 1);
    expect(snap[MonitorModbusIds.motorTemp], 25);

    expect(
      BootSelfCheckLiveCacheSeed.takeStatus()?[BootSelfCheckModbusIds.deviceType],
      1,
    );
    expect(
      BootSelfCheckLiveCacheSeed.takeData()?[MonitorModbusIds.motorTemp],
      25,
    );
  });

  test('group failure soft-fails without seed', () async {
    final modbus = _GroupModbus(failStatus: true, failData: true);
    final snap = await BootSelfCheckModbusSnapshotReader.read(modbus);
    expect(modbus.readGroups, ['status']);
    expect(snap.modbusAvailable, isFalse);
    expect(snap.isUsable, isFalse);
    expect(BootSelfCheckLiveCacheSeed.takeStatus(), isNull);
    expect(BootSelfCheckLiveCacheSeed.takeData(), isNull);
  });

  test('status ok without data is not usable', () async {
    final modbus = _GroupModbus(
      status: _readyStatus(),
      data: const {},
    );

    final snap = await BootSelfCheckModbusSnapshotReader.read(modbus);
    expect(snap.modbusAvailable, isTrue);
    expect(snap.controllerReady, isTrue);
    expect(snap.dataReady, isFalse);
    expect(snap.isUsable, isFalse);
  });

  test('readUntilReady retries when data arrives late', () async {
    final modbus = _GroupModbus(
      status: _readyStatus(),
      data: const {},
    );

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        modbus.data = _readyData;
      }),
    );

    final snap = await BootSelfCheckModbusSnapshotReader.readUntilReady(
      modbus,
      readyBudget: const Duration(seconds: 2),
      retryInterval: const Duration(milliseconds: 20),
    );

    expect(snap.isUsable, isTrue);
    expect(snap.dataReady, isTrue);
    expect(modbus.readGroups.length, greaterThan(2));
  });

  test('readUntilReady retries until controller is usable', () async {
    final modbus = _GroupModbus(openResult: false);
    var flips = 0;
    // Flip open + payload after a couple of failed attempts.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        flips++;
        modbus.openResult = true;
        modbus.status = _readyStatus();
        modbus.data = _readyData;
      }),
    );

    final snap = await BootSelfCheckModbusSnapshotReader.readUntilReady(
      modbus,
      readyBudget: const Duration(seconds: 2),
      retryInterval: const Duration(milliseconds: 20),
    );

    expect(flips, 1);
    expect(modbus.openCalls, greaterThan(1));
    expect(snap.isUsable, isTrue);
    expect(snap[BootSelfCheckModbusIds.deviceType], 1);
  });

  test('readUntilReady retries when device.type not yet ready', () async {
    final modbus = _GroupModbus(
      status: _readyStatus(deviceType: 0),
      data: _readyData,
    );

    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 40), () {
        modbus.status = _readyStatus(deviceType: 2);
      }),
    );

    final snap = await BootSelfCheckModbusSnapshotReader.readUntilReady(
      modbus,
      readyBudget: const Duration(seconds: 2),
      retryInterval: const Duration(milliseconds: 20),
    );

    expect(snap.isUsable, isTrue);
    expect(snap[BootSelfCheckModbusIds.deviceType], 2);
  });

  test('readUntilReady gives up after budget when still unavailable', () async {
    final modbus = _GroupModbus(openResult: false);

    final snap = await BootSelfCheckModbusSnapshotReader.readUntilReady(
      modbus,
      readyBudget: const Duration(milliseconds: 80),
      retryInterval: const Duration(milliseconds: 20),
    );

    expect(snap.isUsable, isFalse);
    expect(modbus.openCalls, greaterThan(1));
  });

  test('readUntilReady stops early when cancelled', () async {
    final modbus = _GroupModbus(openResult: false);
    var cancelled = false;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 30), () {
        cancelled = true;
      }),
    );

    final snap = await BootSelfCheckModbusSnapshotReader.readUntilReady(
      modbus,
      readyBudget: const Duration(seconds: 5),
      retryInterval: const Duration(milliseconds: 20),
      shouldCancel: () => cancelled,
    );

    expect(snap.isUsable, isFalse);
    expect(modbus.openCalls, lessThan(20));
  });
}
