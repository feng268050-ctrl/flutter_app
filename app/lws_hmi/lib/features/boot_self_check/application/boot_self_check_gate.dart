import 'dart:async';

import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_boot_marker.dart';

/// Process-wide gate so overlapping warn/camera monitors can defer (lws-ui
/// `BootSelfCheckGate`). [AppServices.ensureModbusLive] also no-ops while
/// [isActive] so continuous RTU poll does not fight self-check group reads.
///
/// Self-check runs once per HMI process start (not once per OS boot). A new
/// process always shows the dialog again when settings allow it.
abstract final class BootSelfCheckGate {
  static bool _active = false;
  static bool _completedInProcess = false;

  static bool get isActive => _active;

  static bool get isCompletedInProcess => _completedInProcess;

  /// Legacy tmpfs marker (no longer used to skip the dialog).
  static bool get hasCompletedThisBoot => BootSelfCheckBootMarker.exists();

  /// Skip starting self-check only when already done in this process.
  static bool get shouldSkip => _completedInProcess;

  static void setActive(bool active) {
    _active = active;
  }

  /// Mark complete for this process (does not persist across HMI restarts).
  static void markCompletedInProcess() {
    _completedInProcess = true;
    _active = false;
  }

  /// Wait until Home bootstrap has finished self-check (or skipped it).
  ///
  /// Use before presenting non-queue dialogs that must not appear over Safety
  /// Tips / Boot Self-Check (lws-ui home prompts wait on the same condition).
  static Future<void> waitUntilCompletedInProcess({
    Duration pollInterval = const Duration(milliseconds: 40),
  }) async {
    while (!_completedInProcess) {
      await Future<void>.delayed(pollInterval);
    }
    while (_active) {
      await Future<void>.delayed(pollInterval);
    }
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
    if (isCompletedInProcess) {
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
