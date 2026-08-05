import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Dedicated whole-device OTA page — no laser/job controls.
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

    return PopScope(
      canPop: _canPop && !complete,
      child: Scaffold(
        backgroundColor: CyberColors.fillSolidTop,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.systemUpgradeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CyberColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _statusLabel(l10n, progress),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CyberColors.textSecondary,
                        fontSize: 18,
                      ),
                    ),
                    if (showPercent) ...[
                      const SizedBox(height: 24),
                      LinearProgressIndicator(
                        value: progress.percent.clamp(0, 100) / 100.0,
                        minHeight: 8,
                        backgroundColor:
                            CyberColors.textSecondary.withOpacity(0.25),
                        color: CyberColors.textPrimary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${progress.percent.clamp(0, 100)}%',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CyberColors.textSecondary,
                        ),
                      ),
                    ] else if (!failed && !complete) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: CircularProgressIndicator(
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    ],
                    if (failed && progress.message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        progress.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CyberColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (complete) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.otaUpgradeRebootHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: CyberColors.textSecondary,
                        ),
                      ),
                    ],
                    if (failed) ...[
                      const SizedBox(height: 28),
                      Center(
                        child: CyberButton(
                          variant: CyberButtonVariant.primary,
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              AppRoutes.home,
                              (route) => false,
                            );
                          },
                          child: Text(l10n.closeText),
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
    );
  }
}
