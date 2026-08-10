import 'package:cyber_ota/cyber_ota.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/features/system_ota/application/system_ota_coordinator.dart';
import 'package:lws_hmi/features/system_ota/infrastructure/ota_manifest_url.dart';
import 'package:lws_hmi/features/system_ota/presentation/system_upgrade_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Product Home: when “Automatically check for updates” is on, tip → Settings
/// System Upgrade page (available state; Update Now / Later on the page).
///
/// Auto-check runs **once per HMI process** (typically once per boot). Later /
/// dismiss / go-to-Settings all consume the attempt so returning to Home does
/// not re-prompt (TipDialogHost pop also fires Home [didPopNext]).
abstract final class SystemOtaHomeBootstrap {
  static bool _autoPromptConsumed = false;

  /// Test helper.
  static void resetAutoPromptForTest() {
    _autoPromptConsumed = false;
  }

  static Future<void> checkAndPromptIfNeeded(BuildContext context) async {
    if (_autoPromptConsumed) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    final misc = MiscSettingsScope.maybeOf(context);
    if (misc == null || !misc.autoCheckOtaUpdate) {
      return;
    }
    if (SystemOtaCoordinator.instance.isSessionActive) {
      return;
    }

    final queue = GlobalPromptScope.maybeOf(context);
    if (queue == null) {
      return;
    }

    final manifestUrl = _resolveManifestUrl(context);
    if (manifestUrl == null) {
      return;
    }

    late final CheckUpdateResult result;
    try {
      result = await SystemOtaCoordinator.instance.checkForUpdate(
        manifestUrl: manifestUrl,
      );
    } catch (e, st) {
      debugPrint('SystemOtaHomeBootstrap: check failed: $e\n$st');
      return;
    }
    // One-shot auto-check for this process (no update or tip either way).
    _autoPromptConsumed = true;
    if (!result.hasUpdate || result.manifest == null || !context.mounted) {
      return;
    }
    final manifest = result.manifest!;

    await queue.enqueue(
      id: GlobalPromptIds.systemOta,
      present: (host) async {
        if (SystemOtaCoordinator.instance.isSessionActive) {
          return;
        }
        final ctx = host.context;
        if (!ctx.mounted) {
          return;
        }

        final go = await _showGoToSettingsTip(
          context: ctx,
          versionLabel: manifest.displayTitle,
        );
        if (!go || !ctx.mounted) {
          return;
        }

        await _openSettingsUpgradePage(ctx, manifest);
      },
    );
  }

  static String? _resolveManifestUrl(BuildContext context) {
    return OtaManifestUrl.resolve();
  }

  static Future<bool> _showGoToSettingsTip({
    required BuildContext context,
    required String versionLabel,
  }) async {
    final result = await TipDialogHost.showDarkPrompt<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return UpgradeCheckDialog(
          title: l10n.autoOtaUpdateDialogTitle,
          body: Text(l10n.autoOtaUpdateDialogMessage(versionLabel)),
          actions: [
            HmiButton(
              label: l10n.otaUpdateLater,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            HmiButton(
              label: l10n.goToSettings,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  static Future<void> _openSettingsUpgradePage(
    BuildContext context,
    OtaManifest manifest,
  ) async {
    // Pass nested page via Settings args — do not await settings then push
    // (pushNamed completes only when Settings is popped).
    await Navigator.of(context, rootNavigator: true).pushNamed(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialNestedPage: SystemUpgradePage(initialManifest: manifest),
      ),
    );
  }
}
