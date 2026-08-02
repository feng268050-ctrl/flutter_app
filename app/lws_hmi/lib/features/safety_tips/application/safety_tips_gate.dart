/// Process-scoped gate for startup Safety Tips (lws-ui `SafetyTipsActivity`).
///
/// Shown once per HMI process start — no disk persistence, matching lws-ui.
/// While [isActive], global prompts must not present (lws-ui suppresses warn
/// dialogs on SafetyTips; HMI also blocks register/bind/Wi‑Fi tips).
abstract final class SafetyTipsGate {
  static bool _active = false;
  static bool _acceptedThisProcess = false;
  static bool _skipForTest = false;

  static bool get isActive => _active;

  static bool get hasAcceptedThisProcess => _acceptedThisProcess;

  /// When true, [SafetyTipsCoordinator] skips the overlay (widget tests).
  static bool get shouldSkip => _skipForTest || _acceptedThisProcess;

  static void setActive(bool active) {
    _active = active;
  }

  static void markAccepted() {
    _acceptedThisProcess = true;
    _active = false;
  }

  static void resetForTest({bool skip = false}) {
    _active = false;
    _acceptedThisProcess = false;
    _skipForTest = skip;
  }
}
