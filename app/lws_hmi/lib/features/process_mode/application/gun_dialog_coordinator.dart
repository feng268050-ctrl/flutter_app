import 'dart:async';

import 'package:cyber_hal/modbus.dart';
import 'package:flutter/widgets.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/monitor/application/machine_status_controller.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/presentation/safety_ground_lock_prompt.dart';
import 'package:lws_hmi/features/process_mode/presentation/work_status_dialog_host.dart';

/// Coordinates gun-switch edges with Live Monitor + safety-ground prompt
/// (Engineer Mode gun ↔ dialog linkage).
///
/// Quick Mode does **not** host this coordinator. CNC pages must not start it
/// (or must [setActive] false).
final class GunDialogCoordinator {
  GunDialogCoordinator({
    required this.deviceControl,
    required this.services,
    required this.contextGetter,
    required this.showGroundLockAlarmGetter,
    this.resetGunLatchOnEnableOff = false,
    this.closeOnEnableOffImmediate = true,
  });

  final DeviceControlController deviceControl;
  final AppServices services;

  /// Host page [BuildContext] (must remain mounted while active).
  final BuildContext? Function() contextGetter;

  /// Reads Misc `showGroundLockAlarm`.
  final bool Function() showGroundLockAlarmGetter;

  /// When true, clears edge latch on Enable OFF so a held gun can re-edge after
  /// re-Enable. Engineer keeps the latch (`false`).
  final bool resetGunLatchOnEnableOff;

  /// When true, Enable OFF cancels pending close and dismisses gun-managed
  /// Live Monitor immediately. When false, uses delayed close like Android
  /// `closeDialogDelayMillis`.
  final bool closeOnEnableOffImmediate;

  bool? _lastGunOn;
  bool _lastLaserEnable = false;
  bool _started = false;
  bool _active = true;

  StreamSubscription<List<ModbusAttributeChange>>? _modbusSub;
  bool _gunSwitchOn = false;
  bool _safetyGroundLocked = false;

  @visibleForTesting
  bool? get lastGunOn => _lastGunOn;

  @visibleForTesting
  bool get gunSwitchOn => _gunSwitchOn;

  @visibleForTesting
  bool get safetyGroundLocked => _safetyGroundLocked;

  /// Start Modbus watch + device-control listener.
  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _lastLaserEnable = deviceControl.laserEnable;
    deviceControl.addListener(_onDeviceControlChanged);
    try {
      await services.ensureModbusLive();
      final stream = await services.modbus.watchAttributes(
        ids: const [
          MachineStatusIds.gunSwitchOn,
          MachineStatusIds.safetyGroundLock,
        ],
      );
      _modbusSub = stream.listen(_onModbusChanges);
    } catch (e) {
      debugPrint('gun-dialog: modbus watch failed: $e');
    }
  }

  /// Pause edge handling (e.g. host left the process page).
  void setActive(bool active) {
    if (_active == active) {
      return;
    }
    _active = active;
    if (!active) {
      WorkStatusDialogHost.cancelPendingClose();
      WorkStatusDialogHost.closeDialog();
      SafetyGroundLockPrompt.reset();
      _lastGunOn = null;
    }
  }

  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    deviceControl.removeListener(_onDeviceControlChanged);
    unawaited(_modbusSub?.cancel() ?? Future<void>.value());
    _modbusSub = null;
    WorkStatusDialogHost.cancelPendingClose();
    WorkStatusDialogHost.closeDialog();
    WorkStatusDialogHost.clearInstance();
    SafetyGroundLockPrompt.reset();
    _lastGunOn = null;
  }

  void dispose() => stop();

  /// Feed synthetic inputs (unit tests / fakeAsync).
  @visibleForTesting
  void handleInputs({
    required bool laserEnable,
    required bool gunOn,
    required bool safetyGroundLocked,
    required bool showGroundLockAlarm,
  }) {
    _gunSwitchOn = gunOn;
    _safetyGroundLocked = safetyGroundLocked;
    _apply(
      laserEnable: laserEnable,
      showGroundLockAlarm: showGroundLockAlarm,
    );
  }

  void _onDeviceControlChanged() {
    if (!_started || !_active) {
      return;
    }
    _apply(
      laserEnable: deviceControl.laserEnable,
      showGroundLockAlarm: showGroundLockAlarmGetter(),
    );
  }

  void _onModbusChanges(List<ModbusAttributeChange> changes) {
    if (!_started || !_active || changes.isEmpty) {
      return;
    }
    var dirty = false;
    for (final c in changes) {
      switch (c.id) {
        case MachineStatusIds.gunSwitchOn:
          final on = c.value == true;
          if (_gunSwitchOn != on) {
            _gunSwitchOn = on;
            dirty = true;
          }
        case MachineStatusIds.safetyGroundLock:
          final locked = c.value == true;
          if (_safetyGroundLocked != locked) {
            _safetyGroundLocked = locked;
            dirty = true;
          }
      }
    }
    if (!dirty) {
      return;
    }
    _apply(
      laserEnable: deviceControl.laserEnable,
      showGroundLockAlarm: showGroundLockAlarmGetter(),
    );
  }

  void _apply({
    required bool laserEnable,
    required bool showGroundLockAlarm,
  }) {
    if (!_active) {
      return;
    }

    final enableFell = _lastLaserEnable && !laserEnable;
    _lastLaserEnable = laserEnable;

    if (enableFell) {
      WorkStatusDialogHost.cancelPendingClose();
      if (closeOnEnableOffImmediate) {
        WorkStatusDialogHost.closeDialog();
      } else {
        WorkStatusDialogHost.closeDialogDelayMillis();
      }
      SafetyGroundLockPrompt.reset();
      if (resetGunLatchOnEnableOff) {
        _lastGunOn = null;
      }
      return;
    }

    // Gun edges only while Enable ON (matches Engineer cache listeners).
    if (!laserEnable) {
      return;
    }

    if (_lastGunOn != _gunSwitchOn) {
      _lastGunOn = _gunSwitchOn;
      if (_gunSwitchOn) {
        final ctx = contextGetter();
        if (ctx != null && ctx.mounted) {
          unawaited(WorkStatusDialogHost.showNoConfirmDialog(ctx));
        }
      } else {
        WorkStatusDialogHost.scheduleCloseOnGunOff();
      }
    }

    final ctx = contextGetter();
    if (ctx != null && ctx.mounted) {
      unawaited(
        SafetyGroundLockPrompt.maybeShow(
          ctx,
          laserEnableActive: laserEnable,
          gunSwitchOn: _gunSwitchOn,
          safetyGroundLocked: _safetyGroundLocked,
          alarmEnabled: showGroundLockAlarm,
          services: services,
        ),
      );
    }
  }
}
