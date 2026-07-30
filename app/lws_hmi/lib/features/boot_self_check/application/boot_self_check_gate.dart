import 'dart:async';

import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_boot_marker.dart';

/// Process-wide gate so overlapping warn/camera monitors can defer (lws-ui
/// `BootSelfCheckGate`). [AppServices.ensureModbusLive] also no-ops while
/// [isActive] so continuous RTU poll does not fight self-check group reads.
///
/// Completion is also recorded in [BootSelfCheckBootMarker] so HMI restarts
/// within the same system boot skip the dialog.
abstract final class BootSelfCheckGate {
  static bool _active = false;
  static bool _completedInProcess = false;

  static bool get isActive => _active;

  static bool get isCompletedInProcess => _completedInProcess;

  /// True when the tmpfs boot marker exists (survives HMI process restart).
  static bool get hasCompletedThisBoot => BootSelfCheckBootMarker.exists();

  /// Skip starting self-check: already done in this process or this boot.
  static bool get shouldSkip =>
      _completedInProcess || BootSelfCheckBootMarker.exists();

  static void setActive(bool active) {
    _active = active;
  }

  /// Mark complete for this process and this boot (writes tmpfs marker).
  static void markCompletedInProcess() {
    _completedInProcess = true;
    _active = false;
    BootSelfCheckBootMarker.mark();
  }

  /// Wait until boot self-check is not issuing Modbus group reads.
  ///
  /// Cloud live-cache / other on-demand Modbus callers MUST await this before
  /// touching the RTU bus: [AppServices.ensureModbusLive] alone is not enough
  /// because it only suppresses continuous poll, not concurrent `readGroup`.
  /// When self-check succeeds it offers maps via [BootSelfCheckLiveCacheSeed]
  /// so the live cache can skip re-seeding those groups.
  ///
  /// [armGrace] covers the short gap between App first-frame cloud start and
  /// Home raising [isActive] for the dialog pipeline.
  static Future<void> waitForModbusAccess({
    Duration armGrace = const Duration(seconds: 2),
    Duration pollInterval = const Duration(milliseconds: 40),
  }) async {
    if (isCompletedInProcess || hasCompletedThisBoot) {
      while (isActive) {
        await Future<void>.delayed(pollInterval);
      }
      return;
    }

    final armDeadline = DateTime.now().add(armGrace);
    while (!isActive &&
        !isCompletedInProcess &&
        DateTime.now().isBefore(armDeadline)) {
      await Future<void>.delayed(pollInterval);
    }
    while (isActive) {
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Test / hot-restart hook.
  ///
  /// [clearBootMarker]: when false, only clears in-process state (simulates a
  /// new HMI process after `systemctl restart hmi` within the same boot).
  static void resetForTest({bool clearBootMarker = true}) {
    _active = false;
    _completedInProcess = false;
    if (clearBootMarker) {
      BootSelfCheckBootMarker.clearForTest();
    }
  }
}
