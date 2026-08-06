import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Maps whole-device [OtaPhase] onto [cyber_upgrade_ui] phase ids / progress.
abstract final class SystemOtaUpgradeMapping {
  static const preparing = 'preparing';
  static const download = 'download';
  static const verify = 'verify';
  static const extract = 'extract';
  static const write = 'write';
  static const arm = 'arm';

  /// Host `make upgrade` / progress-only: skip version check + confirm.
  static const UpgradePolicy hostForcePolicy = UpgradePolicy.hostForce;

  /// Operator Settings check → Update Now.
  static const UpgradePolicy operatorPolicy = UpgradePolicy.operator;

  static List<UpgradePhase> phases(AppLocalizations l10n) => [
        UpgradePhase(id: preparing, label: l10n.otaUpgradeStatusPreparing),
        UpgradePhase(id: download, label: l10n.otaUpgradeStatusDownloading),
        UpgradePhase(id: verify, label: l10n.otaUpgradeStatusVerifying),
        UpgradePhase(id: extract, label: l10n.otaUpgradeStatusExtracting),
        UpgradePhase(id: write, label: l10n.otaUpgradeStatusWriting),
        UpgradePhase(id: arm, label: l10n.otaUpgradeStatusArming),
      ];

  static String phaseIdFor(OtaPhase phase) {
    return switch (phase) {
      OtaPhase.idle || OtaPhase.preparing || OtaPhase.checking => preparing,
      OtaPhase.transferring => download,
      OtaPhase.verifying => verify,
      OtaPhase.extracting => extract,
      OtaPhase.writing => write,
      OtaPhase.arming || OtaPhase.ok => arm,
      OtaPhase.fail => write,
    };
  }

  static String statusLabel(AppLocalizations l10n, OtaProgress progress) {
    if (progress.phase == OtaPhase.writing) {
      return switch (progress.message) {
        'writing rootfs' => l10n.otaUpgradeStatusWritingRootfs,
        'writing kernel' => l10n.otaUpgradeStatusWritingKernel,
        'writing oem' => l10n.otaUpgradeStatusWritingOem,
        _ => l10n.otaUpgradeStatusWriting,
      };
    }
    return switch (progress.phase) {
      OtaPhase.preparing => l10n.otaUpgradeStatusPreparing,
      OtaPhase.checking => l10n.checkUpdate,
      OtaPhase.transferring => l10n.otaUpgradeStatusDownloading,
      OtaPhase.verifying => l10n.otaUpgradeStatusVerifying,
      OtaPhase.extracting => l10n.otaUpgradeStatusExtracting,
      OtaPhase.writing => l10n.otaUpgradeStatusWriting,
      OtaPhase.arming => l10n.otaUpgradeStatusArming,
      OtaPhase.ok => l10n.otaUpgradeStatusComplete,
      OtaPhase.fail => l10n.otaUpgradeStatusFailed,
      OtaPhase.idle => l10n.otaUpgradeStatusPreparing,
    };
  }

  static UpgradeProgress toUpgradeProgress(OtaProgress progress) {
    final phase = progress.phase;
    final failed = phase == OtaPhase.fail;
    final complete = phase == OtaPhase.ok;
    final showPercent = phase == OtaPhase.transferring ||
        phase == OtaPhase.verifying ||
        phase == OtaPhase.extracting ||
        phase == OtaPhase.writing ||
        phase == OtaPhase.arming;
    final indeterminate = !failed &&
        !complete &&
        !showPercent;

    return UpgradeProgress(
      activePhaseId: phaseIdFor(phase),
      percent: showPercent ? progress.percent.clamp(0, 100) : null,
      indeterminate: indeterminate,
      message: progress.message.isEmpty ? null : progress.message,
      isTerminalOk: complete,
      isTerminalFail: failed,
      errorMessage: failed && progress.message.isNotEmpty
          ? progress.message
          : null,
    );
  }
}
