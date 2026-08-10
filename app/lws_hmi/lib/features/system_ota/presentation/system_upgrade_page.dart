import 'dart:async';

import 'package:cyber_hal/sys_info.dart';
import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_upgrade_mapping.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// System Upgrade — Settings chrome; one content card fills remaining height.
///
/// - From Device Information (OS Version): check + apply (auto-check master
///   switch lives on Device Info → Version).
/// - Host `make upgrade` / cleared-stack: [progressOnly] with
///   [SystemOtaUpgradeMapping.hostForcePolicy] (no version check).
class SystemUpgradePage extends StatefulWidget {
  const SystemUpgradePage({
    super.key,
    this.autoCheckOnOpen = false,
    this.initialManifest,
    this.progressOnly = false,
  });

  final bool autoCheckOnOpen;
  final OtaManifest? initialManifest;

  /// Host / WS apply — skip check chrome; uses [UpgradePolicy.hostForce].
  final bool progressOnly;

  @override
  State<SystemUpgradePage> createState() => _SystemUpgradePageState();
}

class _SystemUpgradePageState extends State<SystemUpgradePage> {
  StreamSubscription<OtaProgress>? _sub;
  StreamSubscription<SysInfoUpdate>? _sysSub;
  OtaProgress? _progress;
  OtaManifest? _availableManifest;
  UpgradeCheckUiState _checkUi = UpgradeCheckUiState.idle;
  bool _applyUi = false;
  String _osVersion = kUnavailableDisplay;
  String _kernelVersion = kUnavailableDisplay;

  /// Effective policy for this page entry.
  UpgradePolicy get _policy => widget.progressOnly
      ? SystemOtaUpgradeMapping.hostForcePolicy
      : SystemOtaUpgradeMapping.operatorPolicy;

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
      // Host force: version check must not gate apply.
      assert(!shouldRunVersionCheck(_policy));
    }
    if (widget.initialManifest != null) {
      _availableManifest = widget.initialManifest;
      _checkUi = UpgradeCheckUiState.available;
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
      if (!widget.progressOnly) {
        _startVersionWatch();
      }
      if (!widget.progressOnly &&
          widget.initialManifest == null &&
          (widget.autoCheckOnOpen ||
              (MiscSettingsScope.maybeOf(context)?.autoCheckOtaUpdate ??
                  false))) {
        unawaited(_runCheck());
      }
    });
  }

  void _startVersionWatch() {
    try {
      final services = AppScope.of(context);
      _sysSub = services.sysInfo
          .watch(interval: const Duration(seconds: 5))
          .listen((update) {
        if (!mounted) {
          return;
        }
        setState(() {
          _osVersion = update.snapshot.osVersion ?? kUnavailableDisplay;
          _kernelVersion =
              update.snapshot.kernelRelease ?? kUnavailableDisplay;
        });
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_sysSub?.cancel());
    super.dispose();
  }

  String? _resolveManifestUrl() => OtaManifestUrl.resolve();

  Future<void> _runCheck() async {
    if (_checkUi == UpgradeCheckUiState.checking ||
        SystemOtaCoordinator.instance.isSessionActive) {
      return;
    }
    if (!shouldRunVersionCheck(_policy)) {
      return;
    }
    final url = _resolveManifestUrl();
    if (url == null || url.isEmpty) {
      setState(() {
        _checkUi = UpgradeCheckUiState.unavailable;
        _availableManifest = null;
      });
      return;
    }
    setState(() {
      _checkUi = UpgradeCheckUiState.checking;
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
          _checkUi = UpgradeCheckUiState.available;
          _availableManifest = result.manifest;
        });
      } else {
        setState(() {
          _checkUi = UpgradeCheckUiState.upToDate;
          _availableManifest = null;
        });
      }
    } catch (e, st) {
      debugPrint('SystemUpgradePage: check failed: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _checkUi = UpgradeCheckUiState.failed;
        _availableManifest = null;
      });
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
          _checkUi = UpgradeCheckUiState.available;
        });
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
        backEnabled: _canPop,
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
                          title: l10n.osVersion,
                          value: _osVersion,
                        ),
                        const Divider(
                          height: SettingsDimens.sectionDividerHeight,
                          thickness: SettingsDimens.sectionDividerHeight,
                          indent: 20,
                          endIndent: 20,
                          color: SettingsDimens.sectionDividerColor,
                        ),
                        SettingsValueRow(
                          title: l10n.kernelVersion,
                          value: _kernelVersion,
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
                              : _buildCheckBody(l10n),
                        ),
                      ),
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

  Widget _buildCheckBody(AppLocalizations l10n) {
    final available = _availableManifest;
    final style = context.hmiTypography.settingsRowValue.copyWith(
      color: CyberColors.textSecondary,
      height: 1.4,
    );
    final headlineStyle = context.hmiTypography.sectionTitle.copyWith(
      color: CyberColors.textPrimary,
    );
    final currentLabel =
        _osVersion == kUnavailableDisplay ? '' : _osVersion;

    return UpgradeCheckCard(
      state: _checkUi,
      idleHint: l10n.otaUpgradeIdleHint,
      checkingLabel: l10n.checkingStatus,
      upToDateMessage: l10n.otaAlreadyUpToDate(currentLabel),
      unavailableMessage: l10n.otaCheckUnavailable,
      failedMessage: l10n.otaCheckFailed,
      availableHeadline: available == null
          ? null
          : l10n.otaNewVersionHeadline(available.displayTitle),
      availableBody: available == null
          ? null
          : ((available.content?.trim().isNotEmpty ?? false)
              ? available.content!.trim()
              : l10n.otaUpdateAvailableMessage(
                  currentLabel,
                  available.version,
                )),
      statusStyle: style,
      headlineStyle: headlineStyle,
      actions: _buildCheckFooter(l10n),
    );
  }

  Widget _buildCheckFooter(AppLocalizations l10n) {
    final available = _availableManifest;
    final showUpdateActions =
        _checkUi == UpgradeCheckUiState.available && available != null;
    final checking = _checkUi == UpgradeCheckUiState.checking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showUpdateActions) ...[
            Center(
              child: HmiButton(
                label: l10n.otaUpdateNow,
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 480,
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
                width: 480,
                shape: CyberButtonShape.rounded,
                variant: CyberButtonVariant.secondary,
                onPressed: () {
                  CyberClickSoundRegistry.playClick();
                  setState(() {
                    _availableManifest = null;
                    _checkUi = UpgradeCheckUiState.idle;
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
                width: 480,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                onPressed: checking ? null : () => unawaited(_runCheck()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBody(AppLocalizations l10n) {
    final otaProgress =
        _progress ?? const OtaProgress(phase: OtaPhase.preparing);
    final updateProgress =
        SystemOtaUpgradeMapping.toUpgradeProgress(otaProgress);
    final failed = updateProgress.isTerminalFail;
    final complete = updateProgress.isTerminalOk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: UpgradePhaseProgressView(
            phases: SystemOtaUpgradeMapping.phases(l10n),
            progress: updateProgress,
            statusLabel:
                SystemOtaUpgradeMapping.statusLabel(l10n, otaProgress),
            titleStyle: context.hmiTypography.settingsRowTitle.copyWith(
              color: CyberColors.textPrimary,
            ),
            percentStyle: context.hmiTypography.settingsRowValue.copyWith(
              color: CyberColors.textSecondary,
            ),
            footer: failed
                ? Center(
                    child: HmiButton(
                      label: l10n.closeText,
                      size: HmiButtonSize.medium,
                      shape: CyberButtonShape.rounded,
                      variant: CyberButtonVariant.primary,
                      borderGradientCenter:
                          CyberBorderGradientCenter.topLeftBottomRight,
                      onPressed: _goHome,
                    ),
                  )
                : null,
          ),
        ),
        if (complete)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: UpgradeCompletionTip(
              progress: updateProgress,
              config: UpgradeCompletionConfig.autoReboot(
                rebootNotice: l10n.otaUpgradeRebootHint,
              ),
              style: context.hmiTypography.settingsRowValue.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
