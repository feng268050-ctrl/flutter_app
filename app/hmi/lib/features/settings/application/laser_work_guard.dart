import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';

/// Soft laser-work interrupt (lws-ui `LaserWorkGuard` subset).
///
/// Clears `control.laser_enable` when policy says work is blocked. Full
/// preflight / ready-GPIO parity lands with engineer-mode migration.
abstract final class LaserWorkGuard {
  static const laserEnableAttribute = 'control.laser_enable';

  /// Re-evaluate after a dangerous bypass is turned OFF.
  static Future<void> evaluateAndInterruptIfNeeded({
    required AppServices services,
    required DangerousOperationsSettings dangerous,
    WarnAlarmController? warnAlarm,
  }) async {
    final snap = dangerous.policySnapshot;
    // Without live fault sampling of all sources, use demo/active episode
    // codes from warn controller when available.
    final episodes = warnAlarm?.coordinator.episodes ?? const {};
    final active = <String>{
      for (final e in episodes.values)
        if (e.faultActive) e.code,
    };
    final gas = active.contains(LaserAlarmPolicy.alarmA001);
    final camera = active.contains(LaserAlarmPolicy.alarmC002);
    final lens = active.contains(LaserAlarmPolicy.alarmL001);
    final feeder = active.contains(LaserAlarmPolicy.alarmW001) ||
        active.contains(LaserAlarmPolicy.alarmW002);
    final other = active.any((c) => !LaserAlarmPolicy.isBypassableAlarmCode(c));

    final readyBlocked = LaserAlarmPolicy.isReadyIndicatorBlocked(
      gasBlocking: LaserAlarmPolicy.isGasBlocking(
        gasAlarmActive: gas,
        allowWorkAfterGasAlarm: snap.allowWorkAfterGasAlarm,
      ),
      cameraBlocking: LaserAlarmPolicy.isCameraBlocking(
        cameraAlarmActive: camera,
        allowWorkAfterCameraAlarm: snap.allowWorkAfterCameraAlarm,
      ),
      lensBlocking: LaserAlarmPolicy.isLensBlocking(
        lensAlarmActive: lens,
        allowWorkAfterLensContamination: snap.allowWorkAfterLensContamination,
      ),
      feederBlocking: LaserAlarmPolicy.isFeederBlocking(
        feederAlarmActive: feeder,
        allowWorkAfterFeederAlarm: snap.allowWorkAfterFeederAlarm,
      ),
      otherCodedWarnBlocking: other,
    );
    final blocked = LaserAlarmPolicy.isWorkBlocked(
      keepLaserOnWhileAlarmed: snap.keepLaserOnWhileAlarmed,
      readyIndicatorBlocked: readyBlocked,
    );
    if (!blocked) {
      return;
    }
    try {
      await services.ensureModbusLive();
      final ok = await services.modbus.writeAttribute(
        laserEnableAttribute,
        false,
      );
      if (!ok) {
        debugPrint('LaserWorkGuard: clear laser_enable soft-failed');
      }
    } catch (e) {
      debugPrint('LaserWorkGuard: interrupt failed: $e');
    }
  }
}
