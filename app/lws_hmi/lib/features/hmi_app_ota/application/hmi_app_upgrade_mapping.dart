import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:lws_hmi/features/hmi_app_ota/application/hmi_app_upgrade_coordinator.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Maps HMI app upgrade phases onto [cyber_upgrade_ui] ids / progress.
///
/// Phase list mirrors System OTA chrome: download → verify → extract → write →
/// restart (system uses arm instead of restart).
abstract final class HmiAppUpgradeMapping {
  static const download = 'download';
  static const verify = 'verify';
  static const extract = 'extract';
  static const write = 'write';
  static const restart = 'restart';

  static const UpgradePolicy hostForcePolicy = UpgradePolicy.hostForce;
  static const UpgradePolicy operatorPolicy = UpgradePolicy.operator;

  static List<UpgradePhase> phases(AppLocalizations l10n) => [
        UpgradePhase(id: download, label: l10n.otaUpgradeStatusDownloading),
        UpgradePhase(id: verify, label: l10n.otaUpgradeStatusVerifying),
        UpgradePhase(id: extract, label: l10n.otaUpgradeStatusExtracting),
        UpgradePhase(id: write, label: l10n.otaUpgradeStatusApk),
        UpgradePhase(id: restart, label: l10n.otaUpgradeStatusRestarting),
      ];

  static String phaseIdFor(HmiAppUpgradePhase phase) {
    return switch (phase) {
      HmiAppUpgradePhase.download => download,
      HmiAppUpgradePhase.verify => verify,
      HmiAppUpgradePhase.extract => extract,
      HmiAppUpgradePhase.write => write,
      HmiAppUpgradePhase.restart => restart,
    };
  }

  static String statusLabel(
    AppLocalizations l10n,
    HmiAppUpgradeProgress progress,
  ) {
    if (progress.isTerminalFail) {
      return l10n.otaUpgradeStatusFailed;
    }
    if (progress.isTerminalOk) {
      return l10n.otaUpgradeStatusComplete;
    }
    return switch (progress.phase) {
      HmiAppUpgradePhase.download => l10n.otaUpgradeStatusDownloading,
      HmiAppUpgradePhase.verify => l10n.otaUpgradeStatusVerifying,
      HmiAppUpgradePhase.extract => l10n.otaUpgradeStatusExtracting,
      HmiAppUpgradePhase.write => l10n.otaUpgradeStatusApk,
      HmiAppUpgradePhase.restart => l10n.otaUpgradeStatusRestarting,
    };
  }

  static UpgradeProgress toUpgradeProgress(HmiAppUpgradeProgress progress) {
    final failed = progress.isTerminalFail;
    final complete = progress.isTerminalOk;
    // Same idea as System OTA: show % on transfer + extract + write.
    final showPercent = progress.isRunning &&
        !failed &&
        !complete &&
        (progress.phase == HmiAppUpgradePhase.download ||
            progress.phase == HmiAppUpgradePhase.extract ||
            progress.phase == HmiAppUpgradePhase.write);
    final indeterminate = progress.isRunning &&
        !failed &&
        !complete &&
        !showPercent;

    return UpgradeProgress(
      activePhaseId: phaseIdFor(progress.phase),
      percent: showPercent ? progress.percent.clamp(0, 100) : null,
      indeterminate: indeterminate,
      message: progress.errorMessage,
      isTerminalOk: complete,
      isTerminalFail: failed,
      errorMessage: failed && (progress.errorMessage?.isNotEmpty ?? false)
          ? progress.errorMessage
          : null,
    );
  }
}
