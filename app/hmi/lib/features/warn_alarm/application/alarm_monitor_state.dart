import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/home/application/temp_series.dart';
import 'package:lws_hmi/features/monitor/application/monitor_modbus_ids.dart';
import 'package:lws_hmi/features/monitor/domain/active_alarm.dart';

/// Live Alarm Information snapshot owned by [WarnAlarmController].
///
/// Comm indicators (lws-ui): `null` → idle (empty), `false` → success (ok),
/// `true` → failure (fault). Missing temp samples → idle, not red.
final class AlarmMonitorState extends ChangeNotifier {
  final TempSeries motor = TempSeries();
  final TempSeries motorDriver = TempSeries();
  final TempSeries protectiveMirror = TempSeries();
  final TempSeries collimator = TempSeries();

  bool gunMotorOverTemp = false;
  bool driverOverTemp = false;
  bool protectiveMirrorOverTemp = false;
  bool collimatorOverTemp = false;

  /// Comm faults (`true` = alarm active). `null` = not yet primed → idle UI.
  bool? laserCommFault;
  bool? gunCommFault;
  bool? wireFeederCommFault;

  /// Camera ICMP / IP-camera health (`true` = unreachable). Not a Modbus bit.
  bool? cameraCommFault;

  bool healthOk = true;
  String? healthMessage;

  List<ActiveAlarm> _active = const [];

  List<ActiveAlarm> get activeAlarms => _active;

  void setActiveAlarms(List<ActiveAlarm> alarms) {
    _active = List<ActiveAlarm>.unmodifiable(alarms);
    notifyListeners();
  }

  /// Updates Camera Comm Status (Alarm Information). Idempotent.
  void setCameraCommFault(bool? fault) {
    if (cameraCommFault == fault) {
      return;
    }
    cameraCommFault = fault;
    notifyListeners();
  }

  void applyHealth(ModbusHealth health) {
    healthOk = health.ok;
    healthMessage = health.message;
    notifyListeners();
  }

  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    for (final c in changes) {
      switch (c.id) {
        case MonitorModbusIds.motorTemp:
          motor.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: gunMotorOverTemp,
          );
        case MonitorModbusIds.motorDriverTemp:
          motorDriver.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: driverOverTemp,
          );
        case MonitorModbusIds.protectiveMirrorTemp:
          protectiveMirror.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: protectiveMirrorOverTemp,
          );
        case MonitorModbusIds.collimatorTemp:
          collimator.setCelsius(
            modbusTempCelsius(c.value),
            overTemp: collimatorOverTemp,
          );
        case MonitorModbusIds.motorOverTemp:
          gunMotorOverTemp = c.value == true;
          motor.setOverTemp(gunMotorOverTemp);
        case MonitorModbusIds.driverOverTemp:
          driverOverTemp = c.value == true;
          motorDriver.setOverTemp(driverOverTemp);
        case MonitorModbusIds.protectiveMirrorOverTemp:
          protectiveMirrorOverTemp = c.value == true;
          protectiveMirror.setOverTemp(protectiveMirrorOverTemp);
        case MonitorModbusIds.collimatorOverTemp:
          collimatorOverTemp = c.value == true;
          collimator.setOverTemp(collimatorOverTemp);
        case 'alarm.laser_comm':
          laserCommFault = c.value == true;
        case 'alarm.gun_comm':
          gunCommFault = c.value == true;
        case 'alarm.wire_feeder_comm':
          wireFeederCommFault = c.value == true;
        default:
          break;
      }
    }
    notifyListeners();
  }
}
