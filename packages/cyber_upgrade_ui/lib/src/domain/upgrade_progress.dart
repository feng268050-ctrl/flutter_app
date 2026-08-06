/// Live progress snapshot for [UpgradePhaseProgressView].
class UpgradeProgress {
  const UpgradeProgress({
    required this.activePhaseId,
    this.percent,
    this.indeterminate = false,
    this.message,
    this.isTerminalOk = false,
    this.isTerminalFail = false,
    this.errorMessage,
  });

  /// Id of the active [UpgradePhase].
  final String activePhaseId;

  /// Optional 0–100 when determinate.
  final int? percent;

  /// When true, show indeterminate indicator (ignore [percent]).
  final bool indeterminate;

  /// Optional subtitle (e.g. `writing rootfs`).
  final String? message;

  final bool isTerminalOk;
  final bool isTerminalFail;

  /// Failure detail when [isTerminalFail].
  final String? errorMessage;

  int get clampedPercent {
    final p = percent ?? 0;
    if (p < 0) {
      return 0;
    }
    if (p > 100) {
      return 100;
    }
    return p;
  }
}
