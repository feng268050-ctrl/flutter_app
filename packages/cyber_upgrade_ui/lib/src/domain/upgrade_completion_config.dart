/// What the product should do after a successful apply.
///
/// Channels differ: whole-device OTA shows a tip then **auto-reboots**;
/// control-board flash stays running.
enum UpgradePostApplyAction {
  /// Stay running; no reboot (e.g. control-board Modbus flash).
  none,

  /// Show success notice, then the device reboots automatically (system OTA).
  ///
  /// The apply engine (or App [UpgradePostApplyListener]) performs the reboot;
  /// this is **not** an operator “please reboot manually” prompt.
  autoReboot,
}

/// App-configured copy + post-apply behavior for terminal success / failure.
class UpgradeCompletionConfig {
  const UpgradeCompletionConfig({
    this.postApplyAction = UpgradePostApplyAction.none,
    this.successTitle,
    this.successBody,
    this.successHint,
    this.failureTitle,
    this.failureBody,
    this.autoRebootDelay = const Duration(milliseconds: 1500),
  });

  /// Whole-device OTA: show [rebootNotice], then auto-reboot after [autoRebootDelay].
  const UpgradeCompletionConfig.autoReboot({
    this.successTitle,
    this.successBody,
    required String rebootNotice,
    this.failureTitle,
    this.failureBody,
    this.autoRebootDelay = const Duration(milliseconds: 1500),
  })  : postApplyAction = UpgradePostApplyAction.autoReboot,
        successHint = rebootNotice;

  /// Control-board / camera-style: no reboot; optional success body only.
  const UpgradeCompletionConfig.noReboot({
    this.successTitle,
    this.successBody,
    this.failureTitle,
    this.failureBody,
  })  : postApplyAction = UpgradePostApplyAction.none,
        successHint = null,
        autoRebootDelay = Duration.zero;

  /// Channel-specific finish policy (auto-reboot vs continue running).
  final UpgradePostApplyAction postApplyAction;

  final String? successTitle;
  final String? successBody;

  /// Extra success line — for [autoReboot], the “rebooting soon” notice.
  final String? successHint;

  final String? failureTitle;
  final String? failureBody;

  /// Pause after terminal success before auto-reboot (tip visibility).
  ///
  /// Apply engines SHOULD honor a similar delay when they own reboot.
  final Duration autoRebootDelay;

  bool get willAutoReboot =>
      postApplyAction == UpgradePostApplyAction.autoReboot;
}
