import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_equipment_status.dart';

/// Modbus attribute ids for work-mode equipment chrome (lws-ui DeviceStatus).
abstract final class WorkModeEquipmentIds {
  static const gunSwitchOn = 'machine.gun_switch_on';
  static const groundClampOn = 'machine.safety_ground_lock';
  static const keySwitchOn = 'machine.key_switch_on';
  static const gasFlowOn = 'machine.air_valve_on';
  static const eStopTriggered = 'machine.emergency_stop';

  static const watchIds = <String>[
    gunSwitchOn,
    groundClampOn,
    keySwitchOn,
    gasFlowOn,
    eStopTriggered,
  ];
}

/// Live binder for [WorkModeStatusBar] equipment indicators.
final class WorkModeEquipmentStatusController extends ChangeNotifier {
  WorkModeEquipmentStatusController(this.services);

  final AppServices services;

  WorkModeEquipmentStatus status = WorkModeEquipmentStatus.unknown;

  StreamSubscription<List<ModbusAttributeChange>>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    try {
      await services.ensureModbusLive();
      final stream = await services.modbus.watchAttributes(
        ids: WorkModeEquipmentIds.watchIds,
      );
      _sub = stream.listen(applyChanges);
    } catch (e) {
      debugPrint('work-mode-status: modbus watch failed: $e');
    }
  }

  @visibleForTesting
  void applyChanges(List<ModbusAttributeChange> changes) {
    if (changes.isEmpty) {
      return;
    }
    var next = status;
    for (final c in changes) {
      final on = c.value == true;
      switch (c.id) {
        case WorkModeEquipmentIds.gunSwitchOn:
          next = next.copyWith(gunSwitchOn: on);
        case WorkModeEquipmentIds.groundClampOn:
          next = next.copyWith(groundClampOn: on);
        case WorkModeEquipmentIds.keySwitchOn:
          next = next.copyWith(keySwitchOn: on);
        case WorkModeEquipmentIds.gasFlowOn:
          next = next.copyWith(gasFlowOn: on);
        case WorkModeEquipmentIds.eStopTriggered:
          next = next.copyWith(eStopTriggered: on);
      }
    }
    if (next == status) {
      return;
    }
    status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
