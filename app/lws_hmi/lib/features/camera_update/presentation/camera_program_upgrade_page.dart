import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_applicator.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_coordinator.dart';
import 'package:lws_hmi/features/camera_update/domain/bundled_camera_firmware_version_gate.dart';
import 'package:lws_hmi/features/ip_camera/application/camera_device_info_cache.dart';
import 'package:lws_hmi/features/ip_camera/application/ip_camera_product_session.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Camera program upgrade — Settings chrome like control-board upgrade.
///
/// - Device Information / IP Camera (Camera Version): check + Update Now
///   (auto-check master switch lives on Device Info → Version).
/// - Home auto-detect: [initialOffer] available state.
/// - Host `make upgrade-camera`: [progressOnly] + [UpgradePolicy.hostForce].
class CameraProgramUpgradePage extends StatefulWidget {
  const CameraProgramUpgradePage({
    super.key,
    this.initialOffer,
    this.progressOnly = false,
    this.autoCheckOnOpen = false,
  });

  final CameraProgramFirmwareOffer? initialOffer;
  final bool progressOnly;
  final bool autoCheckOnOpen;

  @override
  State<CameraProgramUpgradePage> createState() =>
      _CameraProgramUpgradePageState();
}

class _CameraProgramUpgradePageState extends State<CameraProgramUpgradePage> {
  static const _transferPhaseId = 'transfer';
  static const _rebootPhaseId = 'reboot';
  static const _waitPhaseId = 'waitOnline';

  StreamSubscription<CameraProgramUpgradeProgress>? _sub;
  CameraProgramUpgradeProgress _progress = CameraProgramUpgradeProgress.idle;
  CameraProgramFirmwareOffer? _availableOffer;
  UpgradeCheckUiState _checkUi = UpgradeCheckUiState.idle;
  bool _applyUi = false;
  String _currentVersionLabel = '—';

  UpgradePolicy get _policy => widget.progressOnly
      ? UpgradePolicy.hostForce
      : UpgradePolicy.operator;

  bool get _showProgress {
    if (widget.progressOnly || _applyUi) {
      return true;
    }
    if (CameraProgramUpgradeCoordinator.instance.isSessionActive) {
      return true;
    }
    return _progress.isRunning ||
        _progress.isTerminalOk ||
        _progress.isTerminalFail;
  }

  @override
  void initState() {
    super.initState();
    final coordinator = CameraProgramUpgradeCoordinator.instance;
    final last = coordinator.lastProgress;
    if (coordinator.isSessionActive || last.isRunning) {
      _progress = last;
      _applyUi = true;
    } else {
      if (last.isTerminalOk || last.isTerminalFail) {
        coordinator.clearProgress();
      }
      _progress = CameraProgramUpgradeProgress.idle;
    }
    if (widget.progressOnly) {
      _applyUi = true;
      assert(!shouldRunVersionCheck(_policy));
    }
    if (widget.initialOffer != null) {
      _availableOffer = widget.initialOffer;
      _checkUi = UpgradeCheckUiState.available;
      _currentVersionLabel = widget.initialOffer!.deviceVersionLabel;
    }
    _sub = coordinator.progress.listen((p) {
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = p;
        if (p.isRunning || p.isTerminalOk || p.isTerminalFail) {
          _applyUi = true;
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    await _refreshCurrentVersion();
    if (!mounted) {
      return;
    }
    if (widget.progressOnly) {
      final pending =
          CameraProgramUpgradeCoordinator.instance.takePendingHostFile();
      if (pending != null) {
        await _startHostFile(pending);
      }
      return;
    }
    if (widget.initialOffer == null &&
        (widget.autoCheckOnOpen ||
            (MiscSettingsScope.maybeOf(context)?.autoCheckOtaUpdate ??
                false))) {
      await _runCheck();
    }
  }

  Future<void> _refreshCurrentVersion() async {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }
    try {
      final product = await services.ensureProductInfo();
      final host = effectiveCameraHost(product);
      if (host.isEmpty) {
        return;
      }
      final cache = CameraDeviceInfoCache();
      try {
        final version = await cache.fetch(host);
        if (!mounted) {
          return;
        }
        setState(() => _currentVersionLabel = version);
      } finally {
        cache.dispose();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    if (!_progress.isRunning) {
      CameraProgramUpgradeCoordinator.instance.clearProgress();
    }
    super.dispose();
  }

  Future<void> _runCheck() async {
    if (_checkUi == UpgradeCheckUiState.checking ||
        CameraProgramUpgradeCoordinator.instance.isSessionActive) {
      return;
    }
    if (!shouldRunVersionCheck(_policy)) {
      return;
    }
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade() &&
        !CameraProgramUpgradeCoordinator.instance.isSessionActive) {
      setState(() {
        _checkUi = UpgradeCheckUiState.unavailable;
        _availableOffer = null;
      });
      return;
    }
    setState(() {
      _checkUi = UpgradeCheckUiState.checking;
      _availableOffer = null;
    });
    try {
      final eval =
          await CameraProgramUpgradeCoordinator.instance.evaluateOffer(
        policy: _policy,
      );
      if (!mounted) {
        return;
      }
      final offer = eval.offer;
      if (offer != null) {
        setState(() {
          _checkUi = UpgradeCheckUiState.available;
          _availableOffer = offer;
          _currentVersionLabel = offer.deviceVersionLabel;
        });
      } else if (eval.cloudCheckFailed) {
        setState(() {
          _checkUi = UpgradeCheckUiState.unavailable;
          _availableOffer = null;
        });
      } else {
        // Distinguish unreachable host vs up-to-date via a second probe.
        final services = AppScope.maybeOf(context);
        if (services != null) {
          final product = await services.ensureProductInfo();
          final host = effectiveCameraHost(product);
          if (host.isEmpty) {
            setState(() {
              _checkUi = UpgradeCheckUiState.unavailable;
              _availableOffer = null;
            });
            return;
          }
        }
        setState(() {
          _checkUi = UpgradeCheckUiState.upToDate;
          _availableOffer = null;
        });
      }
    } catch (e, st) {
      debugPrint('CameraProgramUpgradePage: check failed: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _checkUi = UpgradeCheckUiState.failed;
        _availableOffer = null;
      });
    }
  }

  Future<void> _startUpdate(CameraProgramFirmwareOffer offer) async {
    CyberClickSoundRegistry.playClick();
    if (CameraProgramUpgradeCoordinator.instance.isSessionActive) {
      return;
    }
    setState(() => _applyUi = true);
    try {
      await CameraProgramUpgradeCoordinator.instance.runOfferUpgrade(
        offer,
        policy: _policy,
      );
    } catch (e) {
      debugPrint('CameraProgramUpgradePage: start update failed: $e');
      if (mounted) {
        setState(() {
          _applyUi = false;
          _checkUi = UpgradeCheckUiState.available;
          _progress = CameraProgramUpgradeProgress(
            isTerminalFail: true,
            errorMessage: '$e',
          );
        });
      }
    }
  }

  Future<void> _startHostFile(File file) async {
    final services = AppScope.maybeOf(context);
    var host = '';
    if (services != null) {
      try {
        final product = await services.ensureProductInfo();
        host = effectiveCameraHost(product);
      } catch (_) {}
    }
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : file.path.split('/').last;
    final bundled =
        BundledCameraFirmwareVersionGate.parseFileName(fileName);
    final offer = CameraProgramFirmwareOffer(
      fileName: fileName,
      deviceVersionLabel: _currentVersionLabel,
      bundledVersionLabel: bundled?.label ?? fileName,
      cameraHost: host,
      hostFile: file,
    );
    await _startUpdate(offer);
  }

  bool get _canPop {
    if (_progress.isRunning) {
      return false;
    }
    if (_progress.isTerminalOk) {
      return false;
    }
    return true;
  }

  void _goHome() {
    CameraProgramUpgradeCoordinator.instance.clearProgress();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  String _phaseId(CameraProgramUpgradePhase phase) => switch (phase) {
        CameraProgramUpgradePhase.transfer => _transferPhaseId,
        CameraProgramUpgradePhase.reboot => _rebootPhaseId,
        CameraProgramUpgradePhase.waitOnline => _waitPhaseId,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inProgress = _showProgress;

    return PopScope(
      canPop: _canPop,
      child: SettingsScaffold(
        title: l10n.cameraProgramUpgradeTitle,
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
                          title: l10n.cameraVersion,
                          value: _currentVersionLabel,
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
    final offer = _availableOffer;
    final style = context.hmiTypography.settingsRowValue.copyWith(
      color: CyberColors.textSecondary,
      height: 1.4,
    );
    final headlineStyle = context.hmiTypography.settingsRowTitle.copyWith(
      color: CyberColors.textPrimary,
      fontSize: 22,
    );

    return UpgradeCheckCard(
      state: _checkUi,
      idleHint: l10n.cameraProgramUpgradeIdleHint,
      checkingLabel: l10n.checkingStatus,
      upToDateMessage:
          l10n.cameraProgramAlreadyUpToDate(_currentVersionLabel),
      unavailableMessage: l10n.cameraProgramCheckUnavailable,
      failedMessage: l10n.cameraProgramCheckFailed,
      availableHeadline: offer == null
          ? null
          : l10n.cameraProgramNewVersionHeadline(offer.bundledVersionLabel),
      availableBody: offer == null
          ? null
          : l10n.cameraProgramDialogMessage(
              offer.deviceVersionLabel,
              offer.bundledVersionLabel,
            ),
      statusStyle: style,
      headlineStyle: headlineStyle,
      actions: _buildCheckFooter(l10n),
    );
  }

  Widget _buildCheckFooter(AppLocalizations l10n) {
    final offer = _availableOffer;
    final showUpdateActions =
        _checkUi == UpgradeCheckUiState.available && offer != null;
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
                onPressed: () => unawaited(_startUpdate(offer)),
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
                    _availableOffer = null;
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
    final failed = _progress.isTerminalFail;
    final complete = _progress.isTerminalOk;
    final running = _progress.isRunning;
    final activeId = _phaseId(_progress.phase);
    final transferActive =
        _progress.phase == CameraProgramUpgradePhase.transfer;
    final updateProgress = UpgradeProgress(
      activePhaseId: activeId,
      percent: (running || complete) && transferActive
          ? _progress.percent.clamp(0, 100)
          : null,
      indeterminate: running && !transferActive,
      isTerminalOk: complete,
      isTerminalFail: failed,
      errorMessage: failed
          ? (_progress.errorMessage?.isNotEmpty == true
              ? _progress.errorMessage
              : l10n.cameraProgramFailedMessage)
          : null,
    );

    final statusLabel = complete
        ? l10n.cameraProgramSuccessTitle
        : failed
            ? l10n.cameraProgramFailedTitle
            : switch (_progress.phase) {
                CameraProgramUpgradePhase.transfer =>
                  l10n.cameraProgramTransferTitle,
                CameraProgramUpgradePhase.reboot =>
                  l10n.cameraProgramRebootTitle,
                CameraProgramUpgradePhase.waitOnline =>
                  l10n.cameraProgramWaitOnlineTitle,
              };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: UpgradePhaseProgressView(
            phases: [
              UpgradePhase(
                id: _transferPhaseId,
                label: l10n.cameraProgramTransferTitle,
              ),
              UpgradePhase(
                id: _rebootPhaseId,
                label: l10n.cameraProgramRebootTitle,
              ),
              UpgradePhase(
                id: _waitPhaseId,
                label: l10n.cameraProgramWaitOnlineTitle,
              ),
            ],
            progress: updateProgress,
            statusLabel: statusLabel,
            titleStyle: context.hmiTypography.settingsRowTitle.copyWith(
              color: CyberColors.textPrimary,
              fontSize: 20,
            ),
            percentStyle: context.hmiTypography.settingsRowValue.copyWith(
              color: CyberColors.textSecondary,
            ),
            percentLabel: running && transferActive
                ? l10n.bundledFirmwareProgressPercent(
                    _progress.percent.clamp(0, 100),
                  )
                : null,
            footer: (failed || complete)
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
        if (complete || failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: UpgradeCompletionTip(
              progress: updateProgress,
              config: UpgradeCompletionConfig.noReboot(
                successBody: complete
                    ? l10n.cameraProgramSuccessMessage
                    : null,
                failureBody: failed
                    ? (_progress.errorMessage?.isNotEmpty == true
                        ? _progress.errorMessage
                        : l10n.cameraProgramFailedMessage)
                    : null,
              ),
              style: context.hmiTypography.settingsRowValue.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
          ),
        if (running)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.cameraProgramUpgradingMessage,
              textAlign: TextAlign.center,
              style: context.hmiTypography.settingsRowValue.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
