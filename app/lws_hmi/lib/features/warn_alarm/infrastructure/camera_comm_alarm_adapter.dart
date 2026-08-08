import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

/// Maps HAL [IpCameraController.health] → C002 [AlarmSignalEvent]s.
///
/// Subscribes only to the existing health Stream (no second ICMP timer).
/// [IpCameraHealthPhase.unknown] is ignored (connecting / probe quiet).
///
/// [setSuppressed] freezes edges and clears an active C002 (camera firmware
/// upgrade / intentional downtime).
final class CameraCommAlarmAdapter implements AlarmSignalSource {
  CameraCommAlarmAdapter();

  static const alarmCode = LaserAlarmPolicy.alarmC002;

  final _controller = StreamController<AlarmSignalEvent>.broadcast(sync: true);
  StreamSubscription<IpCameraHealth>? _sub;
  IpCameraController? _camera;

  /// Last emitted fault latch (`null` = not yet primed with healthy/unhealthy).
  bool? _lastFault;
  bool _suppressed = false;

  @override
  Stream<AlarmSignalEvent> get events => _controller.stream;

  bool get isSuppressed => _suppressed;

  /// Bind to the product session camera; replaces any prior subscription.
  Future<void> bind(IpCameraController camera) async {
    await _sub?.cancel();
    _sub = null;
    _camera = camera;
    if (!_suppressed) {
      _apply(camera.currentHealth);
    }
    _sub = camera.health.listen(_apply);
  }

  /// While true, ignore health updates and clear any active C002 episode edge.
  void setSuppressed(bool value) {
    if (_suppressed == value) {
      return;
    }
    _suppressed = value;
    if (value) {
      if (_lastFault == true) {
        _emitFalling();
      }
      return;
    }
    final camera = _camera;
    if (camera != null) {
      _apply(camera.currentHealth);
    }
  }

  /// Test hook: apply a health sample without [bind].
  @visibleForTesting
  void debugApplyHealth(IpCameraHealth health) => _apply(health);

  void _apply(IpCameraHealth health) {
    if (_suppressed) {
      return;
    }
    if (health.phase == IpCameraHealthPhase.unknown) {
      return;
    }
    final fault = health.phase == IpCameraHealthPhase.unhealthy;
    final previous = _lastFault;
    if (previous == null) {
      _lastFault = fault;
      if (!fault) {
        return;
      }
    } else if (previous == fault) {
      return;
    } else {
      _lastFault = fault;
    }

    _emit(active: fault, detail: health.detail);
  }

  void _emitFalling() {
    _lastFault = false;
    _emit(active: false, detail: 'suppressed');
  }

  void _emit({required bool active, String? detail}) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(
      AlarmSignalEvent(
        code: alarmCode,
        active: active,
        kind: active ? AlarmSignalKind.rising : AlarmSignalKind.falling,
        attributeId: 'health.ip_camera',
        labelHint: detail,
      ),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _camera = null;
    _lastFault = null;
    _suppressed = false;
    await _controller.close();
  }
}
