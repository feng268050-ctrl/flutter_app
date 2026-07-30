import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
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
  }) : super();

  final Map<String, Object?> status;
  final Map<String, Object?> data;
  final bool failStatus;
  final bool failData;
  final List<String> readGroups = <String>[];

  @override
  Future<bool> open() async => true;

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

void main() {
  tearDown(BootSelfCheckLiveCacheSeed.resetForTest);

  test('reads status+data groups and offers live-cache seed', () async {
    final modbus = _GroupModbus(
      status: {
        BootSelfCheckModbusIds.deviceType: 1,
        BootSelfCheckModbusIds.laserComm: false,
        BootSelfCheckModbusIds.gunComm: false,
        BootSelfCheckModbusIds.wireFeederComm: false,
        MonitorModbusIds.motorOverTemp: false,
        MonitorModbusIds.driverOverTemp: false,
        MonitorModbusIds.protectiveMirrorOverTemp: false,
        MonitorModbusIds.collimatorOverTemp: false,
      },
      data: {
        MonitorModbusIds.motorTemp: 25,
        MonitorModbusIds.motorDriverTemp: 26,
        MonitorModbusIds.protectiveMirrorTemp: 27,
        MonitorModbusIds.collimatorTemp: 28,
      },
    );

    final snap = await BootSelfCheckModbusSnapshotReader.read(modbus);
    expect(modbus.readGroups, ['status', 'data']);
    expect(snap.modbusAvailable, isTrue);
    expect(snap.controllerReady, isTrue);
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
    expect(snap.modbusAvailable, isFalse);
    expect(BootSelfCheckLiveCacheSeed.takeStatus(), isNull);
    expect(BootSelfCheckLiveCacheSeed.takeData(), isNull);
  });
}
