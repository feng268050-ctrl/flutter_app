import 'dart:async';
import 'dart:io';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/bundled_firmware_version_gate.dart';
import 'package:lws_hmi/features/bundled_firmware/domain/firmware_upgrade_constants.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/modbus/modbus_rtu_client.dart';
import 'package:lws_hmi/modbus/register_address.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Control-board firmware upgrade — Settings chrome like System Upgrade.
///
/// Device Information → Control Board Version opens this page with control /
/// laser / wire-feeder version rows plus check + Update Now (auto-check master
/// switch lives on Device Info → Version).
/// Home auto-detect: [initialOffer] available state.
/// Host `make upgrade-control-board`: [progressOnly] + [UpgradePolicy.hostForce].
class ControlBoardUpgradePage extends StatefulWidget {
  const ControlBoardUpgradePage({
    super.key,
    this.initialOffer,
    this.progressOnly = false,
    this.autoCheckOnOpen = false,
  });

  final ControlBoardFirmwareOffer? initialOffer;
  final bool progressOnly;
  final bool autoCheckOnOpen;

  @override
  State<ControlBoardUpgradePage> createState() =>
      _ControlBoardUpgradePageState();
}

class _ControlBoardUpgradePageState extends State<ControlBoardUpgradePage> {
  static const _transferPhaseId = 'transferring';

  StreamSubscription<ControlBoardUpgradeProgress>? _sub;
  ControlBoardUpgradeProgress _progress = ControlBoardUpgradeProgress.idle;
  ControlBoardFirmwareOffer? _availableOffer;
  UpgradeCheckUiState _checkUi = UpgradeCheckUiState.idle;
  bool _applyUi = false;
  String _currentSwLabel = '—';
  String _laserVersion = kUnavailableDisplay;
  String _wireFeederVersion = kUnavailableDisplay;

  UpgradePolicy get _policy => widget.progressOnly
      ? UpgradePolicy.hostForce
      : UpgradePolicy.operator;

  bool get _showProgress {
    if (widget.progressOnly || _applyUi) {
      return true;
    }
    if (ControlBoardUpgradeCoordinator.instance.isSessionActive) {
      return true;
    }
    return _progress.isRunning ||
        _progress.isTerminalOk ||
        _progress.isTerminalFail;
  }

  @override
  void initState() {
    super.initState();
    final coordinator = ControlBoardUpgradeCoordinator.instance;
    final last = coordinator.lastProgress;
    // Only resume an in-flight session. Do not resurrect terminal success/fail
    // UI from the process-wide singleton after Close / leave.
    if (coordinator.isSessionActive || last.isRunning) {
      _progress = last;
      _applyUi = true;
    } else {
      if (last.isTerminalOk || last.isTerminalFail) {
        coordinator.clearProgress();
      }
      _progress = ControlBoardUpgradeProgress.idle;
    }
    if (widget.progressOnly) {
      _applyUi = true;
      assert(!shouldRunVersionCheck(_policy));
    }
    if (widget.initialOffer != null) {
      _availableOffer = widget.initialOffer;
      _checkUi = UpgradeCheckUiState.available;
      _currentSwLabel = '${widget.initialOffer!.deviceSw}';
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
    await _refreshCurrentSw();
    if (!mounted) {
      return;
    }
    if (widget.progressOnly) {
      final pending =
          ControlBoardUpgradeCoordinator.instance.takePendingHostFile();
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

  Future<void> _refreshCurrentSw() async {
    final services = AppScope.maybeOf(context);
    if (services == null) {
      return;
    }
    try {
      await services.ensureModbusLive();
      final info = await services.modbus.readGroup('info');
      if (!mounted) {
        return;
      }
      final sw = info[FirmwareUpgradeConstants.deviceSw];
      final label = switch (sw) {
        int i => '$i',
        num n => '${n.toInt()}',
        _ => modbusDisplayOrDash(modbusControlCardDisplay(sw)),
      };
      setState(() {
        _currentSwLabel = label == kUnavailableDisplay ? '—' : label;
        _laserVersion = modbusDisplayOrDash(
          modbusVersionStringDisplay(info[ModbusAttributeId.deviceLaserSwVersion]),
        );
        _wireFeederVersion = modbusDisplayOrDash(
          modbusControlCardDisplay(
            info[ModbusAttributeId.deviceWireFeederSwVersion],
          ),
        );
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    // Leaving the page after a finished session must not leave terminal UI
    // stuck on the singleton for the next open.
    if (!_progress.isRunning) {
      ControlBoardUpgradeCoordinator.instance.clearProgress();
    }
    super.dispose();
  }

  Future<void> _runCheck() async {
    if (_checkUi == UpgradeCheckUiState.checking ||
        ControlBoardUpgradeCoordinator.instance.isSessionActive) {
      return;
    }
    if (!shouldRunVersionCheck(_policy)) {
      return;
    }
    if (!FirmwareUpgradeCoordinator.canStartFirmwareUpgrade() &&
        !ControlBoardUpgradeCoordinator.instance.isSessionActive) {
      // Mutex busy with OTA — treat as unavailable check.
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
          await ControlBoardUpgradeCoordinator.instance.evaluateOffer(
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
          _currentSwLabel = '${offer.deviceSw}';
        });
      } else if (eval.cloudCheckFailed) {
        setState(() {
          _checkUi = UpgradeCheckUiState.unavailable;
          _availableOffer = null;
        });
      } else {
        setState(() {
          _checkUi = UpgradeCheckUiState.upToDate;
          _availableOffer = null;
        });
      }
    } catch (e, st) {
      debugPrint('ControlBoardUpgradePage: check failed: $e\n$st');
      if (!mounted) {
        return;
      }
      setState(() {
        _checkUi = UpgradeCheckUiState.failed;
        _availableOffer = null;
      });
    }
  }

  Future<void> _startUpdate(ControlBoardFirmwareOffer offer) async {
    CyberClickSoundRegistry.playClick();
    if (ControlBoardUpgradeCoordinator.instance.isSessionActive) {
      return;
    }
    setState(() => _applyUi = true);
    try {
      await ControlBoardUpgradeCoordinator.instance.runOfferUpgrade(
        offer,
        policy: _policy,
      );
    } catch (e) {
      debugPrint('ControlBoardUpgradePage: start update failed: $e');
      if (mounted) {
        setState(() {
          _applyUi = false;
          _checkUi = UpgradeCheckUiState.available;
          _progress = ControlBoardUpgradeProgress(
            isTerminalFail: true,
            errorMessage: '$e',
          );
        });
      }
    }
  }

  Future<void> _startHostFile(File file) async {
    final fileName = file.path.split('/').last;
    final sw = BundledFirmwareVersionGate.softwareVersion(fileName) ?? 0;
    final offer = ControlBoardFirmwareOffer(
      fileName: fileName,
      deviceSw: int.tryParse(_currentSwLabel) ?? 0,
      bundledSw: sw,
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
    ControlBoardUpgradeCoordinator.instance.clearProgress();
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
        title: l10n.controlBoardUpgradeTitle,
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
                          title: l10n.firmwareVersion,
                          value: _currentSwLabel,
                        ),
                        const Divider(
                          height: SettingsDimens.sectionDividerHeight,
                          thickness: SettingsDimens.sectionDividerHeight,
                          indent: 20,
                          endIndent: 20,
                          color: SettingsDimens.sectionDividerColor,
                        ),
                        SettingsValueRow(
                          title: l10n.laserVersion,
                          value: _laserVersion,
                        ),
                        const Divider(
                          height: SettingsDimens.sectionDividerHeight,
                          thickness: SettingsDimens.sectionDividerHeight,
                          indent: 20,
                          endIndent: 20,
                          color: SettingsDimens.sectionDividerColor,
                        ),
                        SettingsValueRow(
                          title: l10n.wireFeederVersion,
                          value: _wireFeederVersion,
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
    final style = context.hmiTypography.upgradeDescription.copyWith(
      color: CyberColors.textSecondary,
      height: 1.4,
    );
    final headlineStyle = context.hmiTypography.sectionTitle.copyWith(
      color: CyberColors.textPrimary,
    );
    final offerTitle = offer?.title?.trim();
    final offerContent = offer?.content?.trim();

    return UpgradeCheckCard(
      state: _checkUi,
      idleHint: l10n.controlBoardUpgradeIdleHint,
      checkingLabel: l10n.checkingStatus,
      upToDateMessage:
          l10n.controlBoardAlreadyUpToDate(_currentSwLabel),
      unavailableMessage: l10n.controlBoardCheckUnavailable,
      failedMessage: l10n.controlBoardCheckFailed,
      availableHeadline: offer == null
          ? null
          : ((offerTitle != null && offerTitle.isNotEmpty)
              ? offerTitle
              : l10n.controlBoardNewVersionHeadline('${offer.bundledSw}')),
      availableBody: offer == null
          ? null
          : ((offerContent != null && offerContent.isNotEmpty)
              ? offerContent
              : l10n.controlBoardUpdateAvailableMessage(
                  '${offer.deviceSw}',
                  '${offer.bundledSw}',
                )),
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
    final updateProgress = UpgradeProgress(
      activePhaseId: _transferPhaseId,
      percent: (running || complete) ? _progress.percent.clamp(0, 100) : null,
      indeterminate: false,
      isTerminalOk: complete,
      isTerminalFail: failed,
      errorMessage: failed
          ? (_progress.errorMessage?.isNotEmpty == true
              ? _progress.errorMessage
              : l10n.bundledFirmwareFailedMessage)
          : null,
    );

    final statusLabel = complete
        ? l10n.bundledFirmwareSuccessTitle
        : failed
            ? l10n.bundledFirmwareFailedTitle
            : l10n.bundledFirmwareUpgradingTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: UpgradePhaseProgressView(
            phases: [
              UpgradePhase(
                id: _transferPhaseId,
                label: l10n.bundledFirmwareUpgradingTitle,
              ),
            ],
            progress: updateProgress,
            statusLabel: statusLabel,
            titleStyle: context.hmiTypography.settingsRowTitle.copyWith(
              color: CyberColors.textPrimary,
            ),
            percentStyle: context.hmiTypography.settingsRowValue.copyWith(
              color: CyberColors.textSecondary,
            ),
            percentLabel: running
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
                    ? l10n.bundledFirmwareSuccessMessage
                    : null,
                failureBody: failed
                    ? (_progress.errorMessage?.isNotEmpty == true
                        ? _progress.errorMessage
                        : l10n.bundledFirmwareFailedMessage)
                    : null,
              ),
              style: context.hmiTypography.upgradeDescription.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
          ),
        if (running)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.bundledFirmwareUpgradingMessage,
              textAlign: TextAlign.center,
              style: context.hmiTypography.upgradeDescription.copyWith(
                color: CyberColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
