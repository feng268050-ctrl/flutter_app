import 'package:lws_hmi/features/boot_self_check/application/boot_self_check_boot_marker.dart';

/// Process-wide gate so overlapping warn/camera monitors can defer (lws-ui
/// `BootSelfCheckGate`). [AppServices.ensureModbusLive] also no-ops while
/// [isActive] so continuous RTU poll does not fight self-check one-shot reads.
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
