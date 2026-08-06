import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_ui_status.dart';

/// Modbus + camera ids for Monitor → Machine Status (lws-ui fragment parity).
abstract final class MachineStatusIds {
  static const blowPressure = 'telemetry.blow_pressure';
  static const laserCurrent = 'telemetry.laser_current';
  static const laserOn = 'machine.laser_on';
  static const airValveOn = 'machine.air_valve_on';
  static const safetyGroundLock = 'machine.safety_ground_lock';
  static const gunSwitchOn = 'machine.gun_switch_on';
  static const redLightOn = 'machine.red_light_on';
  static const wireFeedingOn = 'machine.wire_feeding_on';

  static const modbusWatchIds = <String>[
    blowPressure,
    laserCurrent,
    laserOn,
    airValveOn,
    safetyGroundLock,
    gunSwitchOn,
    redLightOn,
    wireFeedingOn,
  ];
}

/// Live Machine Status snapshot (gauges + run tiles).
final class MachineStatusController extends ChangeNotifier {
  MachineStatusController(this.services);

  final AppServices services;

  double gasPressureKpa = 0;
  double laserCurrentA = 0;

  /// Tile run bits: `null` → idle; `true` → on (green).
  bool? laserOn;
  bool? blowOn;
  bool? safetyLockOn;
  bool? gunSwitchOn;
  bool? redLightOn;
  bool? wireFeedingOn;
  bool? cameraOn;

  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  StreamSubscription<IpCameraUiStatus>? _cameraSub;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await services.ensureModbusLive();
      final stream = await services.modbus.watchAttributes(
        ids: MachineStatusIds.modbusWatchIds,
      );
      _modbusSub = stream.listen(applyChanges);
    } catch (e) {
      debugPrint('machine-status: modbus watch failed: $e');
    }
    try {
      final cam = await services.ensureIpCamera();
      _applyCamera(cam.currentStatus);
      _cameraSub = cam.status.listen(_applyCamera);
      unawaited(cam.start());
    } catch (e) {
      debugPrint('machine-status: camera status failed: $e');
    }
  }

  /// Pause live watches while the Machine Status tab is hidden.
  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    unawaited(_cameraSub?.cancel() ?? Future<void>.value());
    _modbusSub = null;
    _cameraSub = null;
  }

  @visibleForTesting
  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    var dirty = false;
    for (final c in changes) {
      switch (c.id) {
        case MachineStatusIds.blowPressure:
          gasPressureKpa = _asDouble(c.value);
          dirty = true;
        case MachineStatusIds.laserCurrent:
          laserCurrentA = _asDouble(c.value);
          dirty = true;
        case MachineStatusIds.laserOn:
          laserOn = c.value == true;
          dirty = true;
        case MachineStatusIds.airValveOn:
          blowOn = c.value == true;
          dirty = true;
        case MachineStatusIds.safetyGroundLock:
          safetyLockOn = c.value == true;
          dirty = true;
        case MachineStatusIds.gunSwitchOn:
          gunSwitchOn = c.value == true;
          dirty = true;
        case MachineStatusIds.redLightOn:
          redLightOn = c.value == true;
          dirty = true;
        case MachineStatusIds.wireFeedingOn:
          wireFeedingOn = c.value == true;
          dirty = true;
      }
    }
    if (dirty) {
      notifyListeners();
    }
  }

  void _applyCamera(IpCameraUiStatus status) {
    final next = status.phase == IpCameraUiPhase.connected;
    if (cameraOn == next) {
      return;
    }
    cameraOn = next;
    notifyListeners();
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
  }

  @override
  void dispose() {
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    unawaited(_cameraSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
