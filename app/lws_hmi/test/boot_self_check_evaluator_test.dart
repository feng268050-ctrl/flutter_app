import 'package:flutter_test/flutter_test.dart';
import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_evaluator.dart';
import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';

BootSelfCheckModbusSnapshot _snap({
  int deviceType = 1,
  bool laserAlarm = false,
  bool gunAlarm = false,
  bool wireAlarm = false,
  bool motorOt = false,
  bool driverOt = false,
  bool mirrorOt = false,
  bool collimatorOt = false,
  num? motorTemp = 25,
  num? driverTemp = 25,
  num? mirrorTemp = 25,
  num? collimatorTemp = 25,
  bool modbusAvailable = true,
}) {
  final ready = BootSelfCheckModbusSnapshot.isControllerReady(deviceType);
  return BootSelfCheckModbusSnapshot(
    values: {
      BootSelfCheckModbusIds.deviceType: deviceType,
      BootSelfCheckModbusIds.laserComm: laserAlarm,
      BootSelfCheckModbusIds.gunComm: gunAlarm,
      BootSelfCheckModbusIds.wireFeederComm: wireAlarm,
      MonitorModbusIds.motorTemp: motorTemp,
      MonitorModbusIds.motorDriverTemp: driverTemp,
      MonitorModbusIds.protectiveMirrorTemp: mirrorTemp,
      MonitorModbusIds.collimatorTemp: collimatorTemp,
      MonitorModbusIds.motorOverTemp: motorOt,
      MonitorModbusIds.driverOverTemp: driverOt,
      MonitorModbusIds.protectiveMirrorOverTemp: mirrorOt,
      MonitorModbusIds.collimatorOverTemp: collimatorOt,
    },
    modbusAvailable: modbusAvailable,
    controllerReady: ready,
  );
}

void main() {
  test('checklist has eight Modbus items and no camera', () {
    expect(BootSelfCheckItem.values, hasLength(8));
    expect(
      BootSelfCheckItem.values.map((e) => e.name),
      isNot(contains('cameraComm')),
    );
  });

  test('healthy snapshot passes all items', () {
    final snap = _snap();
    for (final item in BootSelfCheckItem.values) {
      final status = BootSelfCheckEvaluator.evaluateItem(
        item: item,
        snapshot: snap,
      );
      expect(status, BootSelfCheckStatus.pass, reason: item.name);
    }
  });

  test('modbus unavailable fails Modbus items', () {
    final snap = _snap(modbusAvailable: false, deviceType: 0);
    expect(
      BootSelfCheckEvaluator.evaluateItem(
        item: BootSelfCheckItem.pumpComm,
        snapshot: snap,
      ),
      BootSelfCheckStatus.fail,
    );
  });

  test('controller not ready fails controller and dependents', () {
    final snap = _snap(deviceType: 0);
    expect(
      BootSelfCheckEvaluator.evaluateItem(
        item: BootSelfCheckItem.controllerComm,
        snapshot: snap,
      ),
      BootSelfCheckStatus.fail,
    );
    expect(
      BootSelfCheckEvaluator.evaluateItem(
        item: BootSelfCheckItem.gunComm,
        snapshot: snap,
      ),
      BootSelfCheckStatus.fail,
    );
  });

  test('comm alarm fails', () {
    final snap = _snap(gunAlarm: true);
    expect(
      BootSelfCheckEvaluator.evaluateItem(
        item: BootSelfCheckItem.gunComm,
        snapshot: snap,
      ),
      BootSelfCheckStatus.fail,
    );
  });

  test('missing temp fails temperature item', () {
    final snap = _snap(motorTemp: null);
    expect(
      BootSelfCheckEvaluator.evaluateItem(
        item: BootSelfCheckItem.gunMotorTemp,
        snapshot: snap,
      ),
      BootSelfCheckStatus.fail,
    );
  });
}
