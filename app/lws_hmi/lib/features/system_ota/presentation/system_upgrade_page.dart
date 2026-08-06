import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/status_bar/product_page_status_bar.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/work_mode/domain/work_mode_accent.dart';
import 'package:lws_hmi/features/work_mode/presentation/work_mode_status_bar.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Dedicated whole-device OTA progress page — CyberUI chrome, no laser/job controls.
class SystemUpgradePage extends StatefulWidget {
  const SystemUpgradePage({super.key});

  @override
  State<SystemUpgradePage> createState() => _SystemUpgradePageState();
}

class _SystemUpgradePageState extends State<SystemUpgradePage> {
  StreamSubscription<OtaProgress>? _sub;
  OtaProgress? _progress;

  @override
  void initState() {
    super.initState();
    final coordinator = SystemOtaCoordinator.instance;
    _progress = coordinator.lastProgress ??
        const OtaProgress(phase: OtaPhase.preparing);
    _sub = coordinator.uiProgress.listen((p) {
      if (!mounted) {
        return;
      }
      setState(() => _progress = p);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  bool get _canPop {
    final phase = _progress?.phase ?? OtaPhase.preparing;
    return !SystemOtaCoordinator.isNonCancelablePhase(phase);
  }

  String _statusLabel(AppLocalizations l10n, OtaProgress progress) {
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

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = _progress ?? const OtaProgress(phase: OtaPhase.preparing);
    final failed = progress.phase == OtaPhase.fail;
    final complete = progress.phase == OtaPhase.ok;
    final showPercent = progress.phase == OtaPhase.transferring ||
        progress.phase == OtaPhase.verifying ||
        progress.phase == OtaPhase.extracting ||
        progress.phase == OtaPhase.writing ||
        progress.phase == OtaPhase.arming;
    final percent = progress.percent.clamp(0, 100);
    final allowBack = _canPop && !complete;

    return PopScope(
      canPop: allowBack,
      child: Scaffold(
        backgroundColor: CyberColors.fillSolidTop,
        appBar: ProductPageStatusBar(
          title: l10n.systemUpgradeTitle,
          backgroundColor: CyberColors.fillSolidTop,
          foregroundColor: CyberColors.textPrimary,
          toolbarHeight: WorkModeStatusBarDimens.height,
          bottom: const SettingsStatusBarHairline(),
          backLabel: allowBack ? l10n.equipmentStatusBack : null,
          backAccent: WorkModeAccent.weld,
          onBack: allowBack
              ? () {
                  if (failed) {
                    _goHome();
                    return;
                  }
                  Navigator.of(context).maybePop();
                }
              : null,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: SettingsPanel(
                  borderGradientCenter:
                      CyberBorderGradientCenter.topLeftBottomRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _statusLabel(l10n, progress),
                          textAlign: TextAlign.center,
                          style: context.hmiTypography.settingsRowTitle.copyWith(
                            color: CyberColors.textPrimary,
                            fontSize: 22,
                          ),
                        ),
                        if (showPercent) ...[
                          const SizedBox(height: 28),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent / 100.0,
                              minHeight: 10,
                              backgroundColor: CyberColors.textSecondary
                                  .withOpacity(0.25),
                              color: CyberColors.buttonPrimaryFill,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$percent%',
                            textAlign: TextAlign.center,
                            style:
                                context.hmiTypography.settingsRowValue.copyWith(
                              color: CyberColors.textSecondary,
                            ),
                          ),
                        ] else if (!failed && !complete) ...[
                          const SizedBox(height: 28),
                          const Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: CyberColors.buttonPrimaryFill,
                              ),
                            ),
                          ),
                        ],
                        if (failed && progress.message.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            progress.message,
                            textAlign: TextAlign.center,
                            style:
                                context.hmiTypography.settingsRowValue.copyWith(
                              color: CyberColors.textSecondary,
                            ),
                          ),
                        ],
                        if (complete) ...[
                          const SizedBox(height: 16),
                          Text(
                            l10n.otaUpgradeRebootHint,
                            textAlign: TextAlign.center,
                            style:
                                context.hmiTypography.settingsRowValue.copyWith(
                              color: CyberColors.textSecondary,
                            ),
                          ),
                        ],
                        if (failed) ...[
                          const SizedBox(height: 28),
                          Center(
                            child: HmiButton(
                              label: l10n.closeText,
                              size: HmiButtonSize.medium,
                              shape: CyberButtonShape.rounded,
                              variant: CyberButtonVariant.primary,
                              borderGradientCenter: CyberBorderGradientCenter
                                  .topLeftBottomRight,
                              onPressed: _goHome,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
