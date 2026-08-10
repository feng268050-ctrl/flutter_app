import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/device/display_value.dart';
import 'package:lws_hmi/features/hmi_app_ota/application/hmi_app_upgrade_coordinator.dart';
import 'package:lws_hmi/features/hmi_app_ota/application/hmi_app_upgrade_mapping.dart';
import 'package:lws_hmi/features/hmi_app_ota/infrastructure/hmi_app_manifest_url.dart';
import 'package:lws_hmi/features/process_library/application/process_library_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// HMI Upgrade — Settings chrome; HMI Version + Process Library Version.
///
/// - From Device Information (HMI Version): check + apply (auto-check master
///   switch lives on Device Info → Version).
/// - Host `make upgrade-app` / cleared-stack: [progressOnly] with
///   [HmiAppUpgradeMapping.hostForcePolicy] (no version check).
class HmiUpgradePage extends StatefulWidget {
  const HmiUpgradePage({
    super.key,
    this.autoCheckOnOpen = false,
    this.initialManifest,
    this.progressOnly = false,
  });

  final bool autoCheckOnOpen;
  final OtaManifest? initialManifest;

  /// Host / force apply — skip check chrome; uses [UpgradePolicy.hostForce].
  final bool progressOnly;

  @override
  State<HmiUpgradePage> createState() => _HmiUpgradePageState();
}

class _HmiUpgradePageState extends State<HmiUpgradePage> {
  StreamSubscription<HmiAppUpgradeProgress>? _sub;
  HmiAppUpgradeProgress _progress = HmiAppUpgradeProgress.idle;
  OtaManifest? _availableManifest;
  UpgradeCheckUiState _checkUi = UpgradeCheckUiState.idle;
  bool _applyUi = false;
  String _processLibVersion = kUnavailableDisplay;

  UpgradePolicy get _policy => widget.progressOnly
      ? HmiAppUpgradeMapping.hostForcePolicy
      : HmiAppUpgradeMapping.operatorPolicy;

  bool get _showProgress {
    if (widget.progressOnly || _applyUi) {
      return true;
    }
    if (HmiAppUpgradeCoordinator.instance.isSessionActive) {
      return true;
    }
    return _progress.isRunning ||
        _progress.isTerminalOk ||
        _progress.isTerminalFail;
  }

  @override
  void initState() {
    super.initState();
    final coordinator = HmiAppUpgradeCoordinator.instance;
    final last = coordinator.lastProgress;
    if (coordinator.isSessionActive || last.isRunning) {
      _progress = last;
      _applyUi = true;
    } else {
      if (last.isTerminalOk || last.isTerminalFail) {
        coordinator.clearProgress();
      }
      _progress = HmiAppUpgradeProgress.idle;
    }
    if (widget.progressOnly) {
      _applyUi = true;
      assert(!shouldRunVersionCheck(_policy));
    }
    if (widget.initialManifest != null) {
      _availableManifest = widget.initialManifest;
      _checkUi = UpgradeCheckUiState.available;
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
    if (!widget.progressOnly) {
      _refreshProcessLib();
    }
    if (widget.progressOnly) {
      // Host `make upgrade-app` starts download from the coordinator after nav.
      return;
    }
    if (widget.initialManifest == null &&
        (widget.autoCheckOnOpen ||
            (MiscSettingsScope.maybeOf(context)?.autoCheckOtaUpdate ??
                false))) {
      await _runCheck();
    }
  }

  void _refreshProcessLib() {
    try {
      final lib = ProcessLibraryScope.of(context);
      final fromPreset = lib.presets
          .map((p) => p.libraryVersion)
          .whereType<String>()
          .where((v) => v.trim().isNotEmpty)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => null);
      if (!mounted) {
        return;
      }
      setState(() {
        _processLibVersion =
            (fromPreset == null || fromPreset.isEmpty)
                ? kUnavailableDisplay
                : fromPreset;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    if (!_progress.isRunning) {
      HmiAppUpgradeCoordinator.instance.clearProgress();
    }
    super.dispose();
  }

  String? _resolveManifestUrl() => HmiAppManifestUrl.resolve();

  Future<void> _runCheck() async {
    if (_checkUi == UpgradeCheckUiState.checking ||
        HmiAppUpgradeCoordinator.instance.isSessionActive) {
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
      final result = await HmiAppUpgradeCoordinator.instance.checkForUpdate(
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
      debugPrint('HmiUpgradePage: check failed: $e\n$st');
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
    if (HmiAppUpgradeCoordinator.instance.isSessionActive) {
      return;
    }
    setState(() => _applyUi = true);
    final fileName = _fileNameFromUrl(manifest.packageUrl) ??
        'v${OtaManifest.coreVersion(manifest.version) ?? manifest.version}.tar.gz';
    try {
      await HmiAppUpgradeCoordinator.instance.runOfferUpgrade(
        HmiAppUpgradeOffer(
          version: manifest.version,
          fileName: fileName,
          packageUrl: manifest.packageUrl,
        ),
        policy: _policy,
      );
    } catch (e) {
      debugPrint('HmiUpgradePage: start update failed: $e');
      if (mounted) {
        setState(() {
          _applyUi = false;
          _checkUi = UpgradeCheckUiState.available;
        });
      }
    }
  }

  static String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) {
      return null;
    }
    final name = Uri.decodeComponent(uri.pathSegments.last);
    return name.isEmpty ? null : name;
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
    HmiAppUpgradeCoordinator.instance.clearProgress();
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
        title: l10n.hmiUpgradeTitle,
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
                          title: l10n.hmiVersion,
                          value: kHmiVersion,
                        ),
                        const Divider(
                          height: SettingsDimens.sectionDividerHeight,
                          thickness: SettingsDimens.sectionDividerHeight,
                          indent: 20,
                          endIndent: 20,
                          color: SettingsDimens.sectionDividerColor,
                        ),
                        SettingsValueRow(
                          title: l10n.processLibVersion,
                          value: _processLibVersion,
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
    final headlineStyle = context.hmiTypography.settingsRowTitle.copyWith(
      color: CyberColors.textPrimary,
      fontSize: 22,
    );

    return UpgradeCheckCard(
      state: _checkUi,
      idleHint: l10n.otaUpgradeIdleHint,
      checkingLabel: l10n.checkingStatus,
      upToDateMessage: l10n.otaAlreadyUpToDate(kHmiVersion),
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
                  kHmiVersion,
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
    final updateProgress =
        HmiAppUpgradeMapping.toUpgradeProgress(_progress);
    final failed = updateProgress.isTerminalFail;
    final complete = updateProgress.isTerminalOk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: UpgradePhaseProgressView(
            phases: HmiAppUpgradeMapping.phases(l10n),
            progress: updateProgress,
            statusLabel:
                HmiAppUpgradeMapping.statusLabel(l10n, _progress),
            titleStyle: context.hmiTypography.settingsRowTitle.copyWith(
              color: CyberColors.textPrimary,
              fontSize: 20,
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
        if (complete || failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: UpgradeCompletionTip(
              progress: updateProgress,
              config: UpgradeCompletionConfig.noReboot(
                successBody: complete ? l10n.settingsMayRestartApp : null,
                failureBody: failed
                    ? (_progress.errorMessage?.isNotEmpty == true
                        ? _progress.errorMessage
                        : l10n.otaUpgradeStatusFailed)
                    : null,
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
