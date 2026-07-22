import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_hal/ip_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';

/// Maps HAL [IpCameraController.health] → C002 [AlarmSignalEvent]s.
///
/// Subscribes only to the existing health Stream (no second ICMP timer).
/// [IpCameraHealthPhase.unknown] is ignored (connecting / probe quiet).
final class CameraCommAlarmAdapter implements AlarmSignalSource {
  CameraCommAlarmAdapter();

  static const alarmCode = LaserAlarmPolicy.alarmC002;

  final _controller = StreamController<AlarmSignalEvent>.broadcast(sync: true);
  StreamSubscription<IpCameraHealth>? _sub;

  /// Last emitted fault latch (`null` = not yet primed with healthy/unhealthy).
  bool? _lastFault;

  @override
  Stream<AlarmSignalEvent> get events => _controller.stream;

  /// Bind to the product session camera; replaces any prior subscription.
  Future<void> bind(IpCameraController camera) async {
    await _sub?.cancel();
    _sub = null;
    _apply(camera.currentHealth);
    _sub = camera.health.listen(_apply);
  }

  /// Test hook: apply a health sample without [bind].
  @visibleForTesting
  void debugApplyHealth(IpCameraHealth health) => _apply(health);

  void _apply(IpCameraHealth health) {
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

    if (_controller.isClosed) {
      return;
    }
    _controller.add(
      AlarmSignalEvent(
        code: alarmCode,
        active: fault,
        kind: fault ? AlarmSignalKind.rising : AlarmSignalKind.falling,
        attributeId: 'health.ip_camera',
        labelHint: health.detail,
      ),
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _lastFault = null;
    await _controller.close();
  }
}
