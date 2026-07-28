import 'package:flutter/foundation.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/settings/application/dangerous_operations_settings.dart';
import 'package:lws_hmi/features/settings/application/laser_alarm_policy.dart';
import 'package:lws_hmi/features/warn_alarm/application/warn_alarm_controller.dart';
import 'package:lws_hmi/gpio/rgb_led_decision.dart';

/// Why process apply / process-type change is blocked (fail-closed).
enum ProcessChangeBlockReason {
  /// Modbus group read failed or a required bit was missing.
  statusUnavailable,

  /// `control.laser_enable` or `machine.laser_on` is on.
  laserActive,

  /// `machine.wire_feeding_on` is on.
  wireFeeding,
}

/// Soft laser-work interrupt (lws-ui `LaserWorkGuard` subset).
///
/// Clears `control.laser_enable` when policy says work is blocked. Full
/// preflight / ready-GPIO parity lands with engineer-mode migration.
abstract final class LaserWorkGuard {
  static const laserEnableAttribute = 'control.laser_enable';
  static const laserOnAttribute = 'machine.laser_on';
  static const wireFeedingOnAttribute = 'machine.wire_feeding_on';

  /// Fail-closed interlock for changing process type or process parameters.
  ///
  /// Returns `null` when safe; otherwise a typed reason (do not collapse
  /// Modbus failure / wire feed into "laser work in progress").
  static Future<ProcessChangeBlockReason?> processChangeBlock(
    AppServices services,
  ) async {
    await services.ensureModbusLive();
    Map<String, Object?> control;
    Map<String, Object?> status;
    try {
      // Group reads always hit the controller; readAttribute may return cache.
      control = await services.modbus.readGroup('control');
      status = await services.modbus.readGroup('status');
    } catch (_) {
      return ProcessChangeBlockReason.statusUnavailable;
    }
    final laserEnable = control[laserEnableAttribute];
    final laserOn = status[laserOnAttribute];
    final wireFeeding = status[wireFeedingOnAttribute];
    if (laserEnable == null || laserOn == null || wireFeeding == null) {
      return ProcessChangeBlockReason.statusUnavailable;
    }
    if (_isOn(laserEnable) || _isOn(laserOn)) {
      return ProcessChangeBlockReason.laserActive;
    }
    if (_isOn(wireFeeding)) {
      return ProcessChangeBlockReason.wireFeeding;
    }
    return null;
  }

  /// Fail-closed boolean for call sites that only need safe / not safe.
  static Future<bool> isProcessChangeSafe(AppServices services) async {
    return (await processChangeBlock(services)) == null;
  }

  static bool _isOn(Object? value) => value == true || value == 1;

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
    final readyBlocked = RgbLedDecision.readyIndicatorBlockedFromActive(
      activeCodes: active,
      snapshot: snap,
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
