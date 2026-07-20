/// Process-wide gate so overlapping warn/camera monitors can defer (lws-ui
/// `BootSelfCheckGate`). Wire consumers when those monitors land; until then
/// the coordinator still sets/clears [isActive] for future suppressors.
abstract final class BootSelfCheckGate {
  static bool _active = false;
  static bool _completedInProcess = false;

  static bool get isActive => _active;

  static bool get isCompletedInProcess => _completedInProcess;

  static void setActive(bool active) {
    _active = active;
  }

  static void markCompletedInProcess() {
    _completedInProcess = true;
    _active = false;
  }

  /// Test / hot-restart hook.
  static void resetForTest() {
    _active = false;
    _completedInProcess = false;
  }
}
