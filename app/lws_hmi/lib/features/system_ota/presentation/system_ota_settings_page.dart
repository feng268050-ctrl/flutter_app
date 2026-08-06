import 'dart:async';

import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/app_version.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/widgets/settings_chrome.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/platform/cloud/cloud_local_runtime_scope.dart';
import 'package:lws_hmi/platform/cloud/cloud_settings_scope.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';

/// Settings → Device Information → System Upgrade (lws-ui check + Update Now).
class SystemOtaSettingsPage extends StatefulWidget {
  const SystemOtaSettingsPage({super.key});

  @override
  State<SystemOtaSettingsPage> createState() => _SystemOtaSettingsPageState();
}

class _SystemOtaSettingsPageState extends State<SystemOtaSettingsPage> {
  Timer? _autoCheckTimer;
  bool _checkInFlight = false;
  bool _autoCheckInFlight = false;
  OtaManifest? _availableManifest;

  static const _autoCheckInterval = Duration(hours: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _armAutoCheckTimer();
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  void _armAutoCheckTimer() {
    _autoCheckTimer?.cancel();
    final misc = MiscSettingsScope.maybeOf(context);
    if (misc == null || !misc.autoCheckOtaUpdate) {
      return;
    }
    unawaited(_runAutoCheck());
    _autoCheckTimer = Timer.periodic(_autoCheckInterval, (_) {
      unawaited(_runAutoCheck());
    });
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

  Future<void> _runAutoCheck() async {
    if (_autoCheckInFlight ||
        _checkInFlight ||
        SystemOtaCoordinator.instance.isSessionActive) {
      return;
    }
    final manifestUrl = _resolveManifestUrl();
    if (manifestUrl == null) {
      return;
    }
    _autoCheckInFlight = true;
    try {
      final result = await SystemOtaCoordinator.instance.checkForUpdate(
        manifestUrl: manifestUrl,
      );
      if (!mounted) {
        return;
      }
      if (result.hasUpdate && result.manifest != null) {
        setState(() => _availableManifest = result.manifest);
      }
    } catch (_) {
      // Auto-check is best-effort; never auto-apply.
    } finally {
      _autoCheckInFlight = false;
    }
  }

  Future<void> _showMessage({
    required String title,
    required String body,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    await showCyberDialog<void>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: context.hmiTypography.settingsRowTitle.copyWith(
                color: CyberColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(color: CyberColors.textSecondary),
            ),
            const SizedBox(height: 20),
            HmiButton(
              label: l10n.closeText,
              size: HmiButtonSize.small,
              shape: CyberButtonShape.rounded,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkForUpdates() async {
    CyberClickSoundRegistry.playClick();
    final l10n = AppLocalizations.of(context)!;
    if (_checkInFlight) {
      return;
    }

    final manifestUrl = _resolveManifestUrl();
    if (manifestUrl == null) {
      await _showMessage(
        title: l10n.checkUpdate,
        body: l10n.otaCheckUnavailable,
      );
      return;
    }

    if (SystemOtaCoordinator.instance.isSessionActive) {
      await _showMessage(
        title: l10n.checkUpdate,
        body: l10n.otaSessionActive,
      );
      return;
    }

    setState(() {
      _checkInFlight = true;
      _availableManifest = null;
    });

    final CheckUpdateResult result;
    try {
      result = await SystemOtaCoordinator.instance.checkForUpdate(
        manifestUrl: manifestUrl,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _checkInFlight = false);
      await _showMessage(
        title: l10n.checkUpdate,
        body: l10n.otaCheckFailed,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _checkInFlight = false);

    final manifest = result.manifest;
    if (!result.hasUpdate || manifest == null) {
      await _showMessage(
        title: l10n.checkUpdate,
        body: l10n.otaAlreadyUpToDate(kSystemVersion),
      );
      return;
    }

    setState(() => _availableManifest = manifest);
  }

  Future<void> _startUpdate(OtaManifest manifest) async {
    CyberClickSoundRegistry.playClick();
    final l10n = AppLocalizations.of(context)!;
    try {
      await SystemOtaCoordinator.instance.startCloudUpdateFlow(manifest);
    } catch (_) {
      if (!mounted) {
        return;
      }
      await _showMessage(
        title: l10n.systemUpgradeTitle,
        body: l10n.otaUpgradeStatusFailed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final available = _availableManifest;

    return SettingsScaffold(
      title: l10n.systemUpgradeTitle,
      body: SettingsScrollView(
        children: [
          SettingsGroup(
            borderGradientCenter:
                CyberBorderGradientCenter.topLeftBottomRight,
            children: [
              SettingsValueRow(
                title: l10n.systemVersion,
                value: kSystemVersion,
              ),
            ],
          ),
          if (available != null) ...[
            SettingsGroup(
              borderGradientCenter:
                  CyberBorderGradientCenter.bottomLeftTopRight,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.otaUpdateAvailableTitle,
                        style: context.hmiTypography.settingsRowTitle.copyWith(
                          color: CyberColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.otaUpdateAvailableMessage(
                          kSystemVersion,
                          available.version,
                        ),
                        style: context.hmiTypography.settingsRowValue.copyWith(
                          color: CyberColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: HmiButton(
                              label: l10n.otaUpdateLater,
                              size: HmiButtonSize.medium,
                              shape: CyberButtonShape.rounded,
                              variant: CyberButtonVariant.secondary,
                              onPressed: () {
                                CyberClickSoundRegistry.playClick();
                                setState(() => _availableManifest = null);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HmiButton(
                              label: l10n.otaUpdateNow,
                              size: HmiButtonSize.medium,
                              shape: CyberButtonShape.rounded,
                              variant: CyberButtonVariant.primary,
                              borderGradientCenter: CyberBorderGradientCenter
                                  .topLeftBottomRight,
                              onPressed: () =>
                                  unawaited(_startUpdate(available)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              16,
              SettingsDimens.inset,
              0,
            ),
            child: Center(
              child: HmiButton(
                label: _checkInFlight
                    ? l10n.otaUpgradeStatusPreparing
                    : l10n.checkUpdate,
                size: HmiButtonSize.large,
                widthPolicy: HmiButtonWidthPolicy.fixed,
                width: 340,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                borderGradientCenter:
                    CyberBorderGradientCenter.topLeftBottomRight,
                onPressed: _checkInFlight
                    ? null
                    : () => unawaited(_checkForUpdates()),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SettingsDimens.inset,
              14,
              SettingsDimens.inset,
              SettingsDimens.inset,
            ),
            child: Center(
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
                          _armAutoCheckTimer();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
