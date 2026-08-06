import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/presentation/control_board_upgrade_page.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Home / host entry points for control-board firmware upgrade.
///
/// Home auto-detect tip runs **once per HMI process**. Later / dismiss /
/// go-to-Settings consume the attempt so Home [didPopNext] (also fired when
/// TipDialogHost closes) does not re-prompt.
abstract final class BundledFirmwareBootstrap {
  static const UpgradePolicy operatorPolicy = UpgradePolicy.operator;

  static const UpgradePolicy hostForcePolicy = UpgradePolicy.hostForce;

  static bool _homeAutoPromptConsumed = false;

  /// Test helper.
  static void resetHomeAutoPromptForTest() {
    _homeAutoPromptConsumed = false;
  }

  /// On Product Home: tip → Settings control-board upgrade page (Update Now / Later).
  static Future<void> checkAndPromptIfNeeded(
    BuildContext context,
    AppServices services,
  ) async {
    if (_homeAutoPromptConsumed) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (ControlBoardUpgradeCoordinator.instance.isSessionActive ||
        !FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }
    if (!services.modbusLiveAllowed) {
      return;
    }

    final queue = GlobalPromptScope.maybeOf(context);
    if (queue == null) {
      return;
    }

    final offer =
        await ControlBoardUpgradeCoordinator.instance.evaluateOffer(
      policy: operatorPolicy,
    );
    // One-shot home auto-detect for this process.
    _homeAutoPromptConsumed = true;
    if (offer == null || !context.mounted) {
      return;
    }

    await queue.enqueue(
      id: GlobalPromptIds.bundledFirmware,
      present: (host) async {
        if (ControlBoardUpgradeCoordinator.instance.isSessionActive ||
            FirmwareUpgradeCoordinator.isBusy) {
          return;
        }
        final ctx = host.context;
        if (!ctx.mounted) {
          return;
        }

        final go = await _showGoToSettingsTip(
          context: ctx,
          versionLabel: '${offer.bundledSw}',
        );
        if (!go || !ctx.mounted) {
          return;
        }

        await _openSettingsUpgradePage(ctx, offer);
      },
    );
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
          title: l10n.autoControlBoardUpdateDialogTitle,
          body: Text(
            l10n.autoControlBoardUpdateDialogMessage(versionLabel),
          ),
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
    ControlBoardFirmwareOffer offer,
  ) async {
    // Pass nested page via Settings args — do not await settings then push
    // (pushNamed completes only when Settings is popped).
    await Navigator.of(context, rootNavigator: true).pushNamed(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialNestedPage: ControlBoardUpgradePage(initialOffer: offer),
      ),
    );
  }
}
