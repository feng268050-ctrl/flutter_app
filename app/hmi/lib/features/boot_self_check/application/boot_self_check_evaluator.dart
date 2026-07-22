import 'package:lws_hmi/features/boot_self_check/domain/boot_self_check_item.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';

/// Attribute ids read for a boot self-check Modbus snapshot.
abstract final class BootSelfCheckModbusIds {
  static const deviceType = 'device.type';
  static const laserComm = 'alarm.laser_comm';
  static const gunComm = 'alarm.gun_comm';
  static const wireFeederComm = 'alarm.wire_feeder_comm';

  static const all = <String>[
    deviceType,
    laserComm,
    gunComm,
    wireFeederComm,
    MonitorModbusIds.motorTemp,
    MonitorModbusIds.motorDriverTemp,
    MonitorModbusIds.protectiveMirrorTemp,
    MonitorModbusIds.collimatorTemp,
    MonitorModbusIds.motorOverTemp,
    MonitorModbusIds.driverOverTemp,
    MonitorModbusIds.protectiveMirrorOverTemp,
    MonitorModbusIds.collimatorOverTemp,
  ];
}

/// One-shot attribute map used by [BootSelfCheckEvaluator].
final class BootSelfCheckModbusSnapshot {
  const BootSelfCheckModbusSnapshot({
    required this.values,
    required this.modbusAvailable,
    required this.controllerReady,
  });

  final Map<String, Object?> values;
  final bool modbusAvailable;
  final bool controllerReady;

  Object? operator [](String id) => values[id];

  static bool isControllerReady(Object? deviceType) {
    if (deviceType is int) {
      return deviceType > 0;
    }
    if (deviceType is num) {
      return deviceType.toInt() > 0;
    }
    return false;
  }

  static bool hasTempValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is num) {
      return true;
    }
    return false;
  }

  static bool? asAlarmBit(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }
}

/// Pure evaluation of boot self-check items (Modbus only; no camera).
///
/// Undetectable / unavailable results are [BootSelfCheckStatus.fail] (Fault),
/// not skipped — product HMI treats missing telemetry as a fault.
abstract final class BootSelfCheckEvaluator {
  static BootSelfCheckStatus evaluateItem({
    required BootSelfCheckItem item,
    required BootSelfCheckModbusSnapshot? snapshot,
  }) {
    if (snapshot == null || !snapshot.modbusAvailable) {
      return BootSelfCheckStatus.fail;
    }

    if (item == BootSelfCheckItem.controllerComm) {
      return snapshot.controllerReady
          ? BootSelfCheckStatus.pass
          : BootSelfCheckStatus.fail;
    }

    if (!snapshot.controllerReady) {
      return BootSelfCheckStatus.fail;
    }

    switch (item) {
      case BootSelfCheckItem.pumpComm:
        return _commPass(snapshot[BootSelfCheckModbusIds.laserComm]);
      case BootSelfCheckItem.gunComm:
        return _commPass(snapshot[BootSelfCheckModbusIds.gunComm]);
      case BootSelfCheckItem.wireFeederComm:
        return _commPass(snapshot[BootSelfCheckModbusIds.wireFeederComm]);
      case BootSelfCheckItem.motorDriverTemp:
        return _tempPass(
          alarm: snapshot[MonitorModbusIds.driverOverTemp],
          temp: snapshot[MonitorModbusIds.motorDriverTemp],
        );
      case BootSelfCheckItem.gunMotorTemp:
        return _tempPass(
          alarm: snapshot[MonitorModbusIds.motorOverTemp],
          temp: snapshot[MonitorModbusIds.motorTemp],
        );
      case BootSelfCheckItem.protectionMirrorTemp:
        return _tempPass(
          alarm: snapshot[MonitorModbusIds.protectiveMirrorOverTemp],
          temp: snapshot[MonitorModbusIds.protectiveMirrorTemp],
        );
      case BootSelfCheckItem.collimatorTemp:
        return _tempPass(
          alarm: snapshot[MonitorModbusIds.collimatorOverTemp],
          temp: snapshot[MonitorModbusIds.collimatorTemp],
        );
      case BootSelfCheckItem.controllerComm:
        return BootSelfCheckStatus.fail;
    }
  }

  static BootSelfCheckStatus _commPass(Object? alarmBit) {
    final alarm = BootSelfCheckModbusSnapshot.asAlarmBit(alarmBit);
    if (alarm == null) {
      return BootSelfCheckStatus.fail;
    }
    return alarm ? BootSelfCheckStatus.fail : BootSelfCheckStatus.pass;
  }

  static BootSelfCheckStatus _tempPass({
    required Object? alarm,
    required Object? temp,
  }) {
    if (!BootSelfCheckModbusSnapshot.hasTempValue(temp)) {
      return BootSelfCheckStatus.fail;
    }
    final over = BootSelfCheckModbusSnapshot.asAlarmBit(alarm);
    if (over == null) {
      return BootSelfCheckStatus.fail;
    }
    return over ? BootSelfCheckStatus.fail : BootSelfCheckStatus.pass;
  }
}
