import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/features/system_ota/presentation/ota_check_result_dialog.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// System Upgrade — Settings chrome; one content card fills remaining height.
///
/// - From Device Information (System Version): check + auto-check + apply.
/// - Host `make upgrade` / cleared-stack: [progressOnly] (no check chrome).
class SystemUpgradePage extends StatefulWidget {
  const SystemUpgradePage({
    super.key,
    this.autoCheckOnOpen = false,
    this.initialManifest,
    this.progressOnly = false,
  });

  final bool autoCheckOnOpen;
  final OtaManifest? initialManifest;
  final bool progressOnly;

  @override
  State<SystemUpgradePage> createState() => _SystemUpgradePageState();
}

enum _CheckUi {
  idle,
  checking,
  upToDate,
  available,
  unavailable,
  failed,
}

class _SystemUpgradePageState extends State<SystemUpgradePage> {
  StreamSubscription<OtaProgress>? _sub;
  OtaProgress? _progress;
  OtaManifest? _availableManifest;
  _CheckUi _checkUi = _CheckUi.idle;
  bool _applyUi = false;

  bool get _showProgress {
    if (widget.progressOnly || _applyUi) {
      return true;
    }
    if (SystemOtaCoordinator.instance.isSessionActive) {
      return true;
    }
    final phase = _progress?.phase;
    if (phase == null) {
      return false;
    }
    return phase == OtaPhase.preparing ||
        phase == OtaPhase.transferring ||
        phase == OtaPhase.verifying ||
        phase == OtaPhase.extracting ||
        phase == OtaPhase.writing ||
        phase == OtaPhase.arming ||
        phase == OtaPhase.ok;
  }

  @override
  void initState() {
    super.initState();
    final coordinator = SystemOtaCoordinator.instance;
    _progress = coordinator.lastProgress;
    if (widget.progressOnly) {
      _applyUi = true;
    }
    if (widget.initialManifest != null) {
      _availableManifest = widget.initialManifest;
      _checkUi = _CheckUi.available;
    }
    _sub = coordinator.uiProgress.listen((p) {
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = p;
        if (p.phase == OtaPhase.transferring ||
            p.phase == OtaPhase.preparing ||
            p.phase == OtaPhase.verifying ||
            p.phase == OtaPhase.extracting ||
            p.phase == OtaPhase.writing ||
            p.phase == OtaPhase.arming ||
            p.phase == OtaPhase.ok ||
            p.phase == OtaPhase.fail) {
          _applyUi = true;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoCheckOnOpen &&
          widget.initialManifest == null &&
          !widget.progressOnly) {
        unawaited(_runCheck());
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  String? _resolveManifestUrl() {
    final cloudStore = CloudSettingsScope.maybeOf(context);
    if (cloudStore == null) {
      return null;
    }
    final runtime = CloudLocalRuntimeScope.maybeOf(context);
    return OtaManifestUrl.resolve(
      cloudSettings: cloudStore,
      pinnedApiBase: runtime?.pinnedApiBase,
    );
  }

  Future<void> _runCheck() async {
    if (_checkUi == _CheckUi.checking ||
        SystemOtaCoordinator.instance.isSessionActive) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final url = _resolveManifestUrl();
    if (url == null) {
      setState(() {
        _checkUi = _CheckUi.unavailable;
        _availableManifest = null;
      });
      await showOtaCheckFailedDialog(
        context,
        message: l10n.otaCheckUnavailable,
      );
      return;
    }
    setState(() {
      _checkUi = _CheckUi.checking;
      _availableManifest = null;
    });
    try {
      final result = await SystemOtaCoordinator.instance.checkForUpdate(
        manifestUrl: url,
      );
      if (!mounted) {
        return;
      }
      if (result.hasUpdate && result.manifest != null) {
        setState(() {
          _checkUi = _CheckUi.available;
          _availableManifest = result.manifest;
        });
      } else {
        setState(() {
          _checkUi = _CheckUi.upToDate;
          _availableManifest = null;
        });
        await showOtaCheckUpToDateDialog(context);
      }
    } catch (e, st) {
      debugPrint('SystemUpgradePage: check failed: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _checkUi = _CheckUi.failed;
        _availableManifest = null;
      });
      await showOtaCheckFailedDialog(
        context,
        message: l10n.otaCheckFailed,
      );
    }
  }

  Future<void> _startUpdate(OtaManifest manifest) async {
    CyberClickSoundRegistry.playClick();
    if (SystemOtaCoordinator.instance.isSessionActive) {
      return;
    }
    setState(() => _applyUi = true);
    try {
      await SystemOtaCoordinator.instance.startCloudUpdateFlow(
        manifest,
        alreadyOnUpgradePage: true,
      );
    } catch (e) {
      debugPrint('SystemUpgradePage: start update failed: $e');
      if (mounted) {
        setState(() {
          _applyUi = false;
          _checkUi = _CheckUi.available;
        });
        final l10n = AppLocalizations.of(context)!;
        await showOtaCheckFailedDialog(
          context,
          title: l10n.systemUpgradeTitle,
          message: l10n.otaUpgradeStatusFailed,
        );
      }
    }
  }

  bool get _canPop {
    final phase = _progress?.phase ?? OtaPhase.idle;
    if (SystemOtaCoordinator.isNonCancelablePhase(phase)) {
      return false;
    }
    if (phase == OtaPhase.ok) {
      return false;
    }
    return true;
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
    final inProgress = _showProgress;

    return PopScope(
      canPop: _canPop,
      child: SettingsScaffold(
        title: l10n.systemUpgradeTitle,
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            SettingsDimens.inset,
            SettingsDimens.inset,
            SettingsDimens.inset,
            SettingsDimens.inset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SettingsPanel(
                  borderGradientCenter:
                      CyberBorderGradientCenter.topLeftBottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!inProgress) ...[
                        SettingsValueRow(
                          title: l10n.systemVersion,
                          value: kSystemVersion,
                        ),
                        const Divider(
                          height: SettingsDimens.sectionDividerHeight,
                          thickness: SettingsDimens.sectionDividerHeight,
                          indent: 20,
                          endIndent: 20,
                          color: SettingsDimens.sectionDividerColor,
                        ),
                      ],
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: inProgress
                              ? _buildProgressBody(l10n)
                              : _buildCheckStatus(l10n),
                        ),
                      ),
                      if (!inProgress) _buildCheckFooter(l10n),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckStatus(AppLocalizations l10n) {
    final available = _availableManifest;
    final style = context.hmiTypography.settingsRowValue.copyWith(
      color: CyberColors.textSecondary,
      height: 1.4,
    );
    final status = switch (_checkUi) {
      _CheckUi.idle => Text(l10n.otaUpgradeIdleHint, style: style),
      _CheckUi.checking => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: CyberColors.buttonPrimaryFill,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.checkingStatus,
              textAlign: TextAlign.center,
              style: style,
            ),
          ],
        ),
      _CheckUi.upToDate => Text(
          l10n.otaAlreadyUpToDate,
          style: style,
        ),
      _CheckUi.unavailable => Text(l10n.otaCheckUnavailable, style: style),
      _CheckUi.failed => Text(l10n.otaCheckFailed, style: style),
      _CheckUi.available => available == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.otaNewVersionHeadline(available.displayTitle),
                  style: context.hmiTypography.settingsRowTitle.copyWith(
                    color: CyberColors.textPrimary,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (available.content?.trim().isNotEmpty ?? false)
                      ? available.content!.trim()
                      : l10n.otaUpdateAvailableMessage(
                          kSystemVersion,
                          available.version,
                        ),
                  style: style,
                ),
              ],
            ),
    };
    return Align(
      alignment: _checkUi == _CheckUi.checking
          ? Alignment.center
          : Alignment.topCenter,
      child: status,
    );
  }

  Widget _buildCheckFooter(AppLocalizations l10n) {
    final available = _availableManifest;
    final showUpdateActions =
        _checkUi == _CheckUi.available && available != null;
    final checking = _checkUi == _CheckUi.checking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showUpdateActions) ...[
            Center(
              child: HmiButton(
                label: l10n.otaUpdateNow,
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 340,
                shape: CyberButtonShape.rounded,
                variant: CyberButtonVariant.primary,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                onPressed: () => unawaited(_startUpdate(available)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: HmiButton(
                label: l10n.otaUpdateLater,
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 340,
                shape: CyberButtonShape.rounded,
                variant: CyberButtonVariant.secondary,
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  setState(() {
                    _availableManifest = null;
                    _checkUi = _CheckUi.idle;
                  });
                },
              ),
            ),
          ] else ...[
            Center(
              child: HmiButton(
                label: l10n.checkUpdate,
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 340,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                onPressed: checking ? null : () => unawaited(_runCheck()),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: Builder(
              builder: (context) {
                final misc = MiscSettingsScope.maybeOf(context);
                if (misc == null) {
                  return SettingsCheckboxRow(
                    title: l10n.autoCheckOtaUpdate,
                    value: false,
                    onChanged: null,
                  );
                }
                return ListenableBuilder(
                  listenable: misc,
                  builder: (context, _) {
                    return SettingsCheckboxRow(
                      title: l10n.autoCheckOtaUpdate,
                      value: misc.autoCheckOtaUpdate,
                      onChanged: (v) {
                        unawaited(misc.setAutoCheckOtaUpdate(v ?? false));
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBody(AppLocalizations l10n) {
    final progress =
        _progress ?? const OtaProgress(phase: OtaPhase.preparing);
    final failed = progress.phase == OtaPhase.fail;
    final complete = progress.phase == OtaPhase.ok;
    final showPercent = progress.phase == OtaPhase.transferring ||
        progress.phase == OtaPhase.verifying ||
        progress.phase == OtaPhase.extracting ||
        progress.phase == OtaPhase.writing ||
        progress.phase == OtaPhase.arming;
    final percent = progress.percent.clamp(0, 100);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          _statusLabel(l10n, progress),
          textAlign: TextAlign.center,
          style: context.hmiTypography.settingsRowTitle.copyWith(
            color: CyberColors.textPrimary,
            fontSize: 20,
          ),
        ),
        if (showPercent) ...[
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100.0,
              minHeight: 10,
              backgroundColor:
                  CyberColors.textSecondary.withOpacity(0.25),
              color: CyberColors.buttonPrimaryFill,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$percent%',
            textAlign: TextAlign.center,
            style: context.hmiTypography.settingsRowValue.copyWith(
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
            style: context.hmiTypography.settingsRowValue.copyWith(
              color: CyberColors.textSecondary,
            ),
          ),
        ],
        if (complete) ...[
          const SizedBox(height: 16),
          Text(
            l10n.otaUpgradeRebootHint,
            textAlign: TextAlign.center,
            style: context.hmiTypography.settingsRowValue.copyWith(
              color: CyberColors.textSecondary,
            ),
          ),
        ],
        if (failed) ...[
          const SizedBox(height: 24),
          Center(
            child: HmiButton(
              label: l10n.closeText,
              size: HmiButtonSize.medium,
              shape: CyberButtonShape.rounded,
              variant: CyberButtonVariant.primary,
              borderGradientCenter:
                  CyberBorderGradientCenter.topLeftBottomRight,
              onPressed: _goHome,
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }
}
