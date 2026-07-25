import 'package:cyber_hal/cyber_hal.dart';
import 'package:cyber_hal/modbus.dart';
import 'package:cyber_hal/stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';

class _OfflineModbus extends ModbusRtuClient {
  _OfflineModbus() : super();

  @override
  Future<void> ensurePolling() async {}

  @override
  Future<void> applyHealthWindowMode(String? mode) async {}

  @override
  Future<Stream<List<ModbusAttributeChange>>> watchAttributes({
    Iterable<String>? ids,
  }) async =>
      const Stream.empty();
}

BoardProfile _testProfile() => BoardProfile.fromJsonString('''
{
  "board_id": "test",
  "platform": "linux",
  "capabilities": [],
  "helpers": {},
  "configs": {}
}
''');

void main() {
  test('applyChanges maps gauges and run tiles', () {
    final services = AppServices(
      boardProfile: _testProfile(),
      modbusClient: _OfflineModbus(),
      sysInfo: StubSysInfo(),
    );
    final ctrl = MachineStatusController(services);
    ctrl.applyChanges(const [
      ModbusAttributeChange(id: MachineStatusIds.blowPressure, value: 42),
      ModbusAttributeChange(id: MachineStatusIds.laserCurrent, value: 12.5),
      ModbusAttributeChange(id: MachineStatusIds.laserOn, value: true),
      ModbusAttributeChange(id: MachineStatusIds.airValveOn, value: false),
      ModbusAttributeChange(id: MachineStatusIds.safetyGroundLock, value: true),
      ModbusAttributeChange(id: MachineStatusIds.gunSwitchOn, value: true),
      ModbusAttributeChange(id: MachineStatusIds.redLightOn, value: false),
      ModbusAttributeChange(id: MachineStatusIds.wireFeedingOn, value: true),
    ]);
    expect(ctrl.gasPressureKpa, 42);
    expect(ctrl.laserCurrentA, 12.5);
    expect(ctrl.laserOn, isTrue);
    expect(ctrl.blowOn, isFalse);
    expect(ctrl.safetyLockOn, isTrue);
    expect(ctrl.gunSwitchOn, isTrue);
    expect(ctrl.redLightOn, isFalse);
    expect(ctrl.wireFeedingOn, isTrue);
    ctrl.dispose();
  });
}
