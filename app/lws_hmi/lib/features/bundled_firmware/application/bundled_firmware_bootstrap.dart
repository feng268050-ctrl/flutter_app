import 'package:cyber_ui/cyber_ui.dart';
import 'package:cyber_upgrade_ui/cyber_upgrade_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_routes.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/bundled_firmware/application/control_board_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/application/firmware_upgrade_coordinator.dart';
import 'package:lws_hmi/features/bundled_firmware/presentation/control_board_upgrade_page.dart';
import 'package:lws_hmi/features/camera_update/application/camera_program_upgrade_coordinator.dart';
import 'package:lws_hmi/features/camera_update/presentation/camera_program_upgrade_page.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_ids.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_scope.dart';
import 'package:lws_hmi/features/settings/application/misc_settings_scope.dart';
import 'package:lws_hmi/features/settings/presentation/settings_page.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Home / host entry points for control-board + camera firmware upgrade.
///
/// Home auto-detect tips run **once per channel per HMI process**. Control-board
/// is preferred when both candidates exist; camera runs on a later Home visit
/// after the CB tip is settled or when no CB candidate remains.
abstract final class BundledFirmwareBootstrap {
  static const UpgradePolicy operatorPolicy = UpgradePolicy.operator;

  static const UpgradePolicy hostForcePolicy = UpgradePolicy.hostForce;

  static bool _homeAutoPromptConsumed = false;
  static bool _homeCameraAutoPromptConsumed = false;

  /// Test helper.
  static void resetHomeAutoPromptForTest() {
    _homeAutoPromptConsumed = false;
    _homeCameraAutoPromptConsumed = false;
  }

  /// On Product Home: tip → Settings upgrade page (Update Now / Later).
  static Future<void> checkAndPromptIfNeeded(
    BuildContext context,
    AppServices services,
  ) async {
    if (!context.mounted) {
      return;
    }
    if (ControlBoardUpgradeCoordinator.instance.isSessionActive ||
        CameraProgramUpgradeCoordinator.instance.isSessionActive ||
        !FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }

    final misc = MiscSettingsScope.maybeOf(context);
    if (misc == null || !misc.autoCheckOtaUpdate) {
      return;
    }

    final queue = GlobalPromptScope.maybeOf(context);
    if (queue == null) {
      return;
    }

    // Prefer control-board tip first (once per process when master auto-check is on).
    if (!_homeAutoPromptConsumed && services.modbusLiveAllowed) {
      final eval =
          await ControlBoardUpgradeCoordinator.instance.evaluateOffer(
        policy: operatorPolicy,
      );
      _homeAutoPromptConsumed = true;
      final offer = eval.offer;
      if (offer != null && context.mounted) {
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
              title: (l10n) => l10n.autoControlBoardUpdateDialogTitle,
              body: (l10n) => l10n.autoControlBoardUpdateDialogMessage(
                '${offer.bundledSw}',
              ),
            );
            if (!go || !ctx.mounted) {
              return;
            }

            await _openSettingsControlBoardPage(ctx, offer);
          },
        );
        // Defer camera until next Home visit after CB tip settles.
        return;
      }
    } else if (!_homeAutoPromptConsumed) {
      _homeAutoPromptConsumed = true;
    }

    if (_homeCameraAutoPromptConsumed || !context.mounted) {
      return;
    }
    if (CameraProgramUpgradeCoordinator.instance.isSessionActive ||
        !FirmwareUpgradeCoordinator.canStartFirmwareUpgrade()) {
      return;
    }

    final cameraEval =
        await CameraProgramUpgradeCoordinator.instance.evaluateOffer(
      policy: operatorPolicy,
    );
    _homeCameraAutoPromptConsumed = true;
    final cameraOffer = cameraEval.offer;
    if (cameraOffer == null || !context.mounted) {
      return;
    }

    await queue.enqueue(
      id: GlobalPromptIds.cameraProgramFirmware,
      present: (host) async {
        if (CameraProgramUpgradeCoordinator.instance.isSessionActive ||
            FirmwareUpgradeCoordinator.isBusy) {
          return;
        }
        final ctx = host.context;
        if (!ctx.mounted) {
          return;
        }

        final go = await _showGoToSettingsTip(
          context: ctx,
          title: (l10n) => l10n.autoCameraProgramUpdateDialogTitle,
          body: (l10n) => l10n.autoCameraProgramUpdateDialogMessage(
            cameraOffer.bundledVersionLabel,
          ),
        );
        if (!go || !ctx.mounted) {
          return;
        }

        await _openSettingsCameraPage(ctx, cameraOffer);
      },
    );
  }

  static Future<bool> _showGoToSettingsTip({
    required BuildContext context,
    required String Function(AppLocalizations l10n) title,
    required String Function(AppLocalizations l10n) body,
  }) async {
    final result = await TipDialogHost.showDarkPrompt<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return UpgradeCheckDialog(
          title: title(l10n),
          body: Text(body(l10n)),
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

  static Future<void> _openSettingsControlBoardPage(
    BuildContext context,
    ControlBoardFirmwareOffer offer,
  ) async {
    await Navigator.of(context, rootNavigator: true).pushNamed(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialNestedPage: ControlBoardUpgradePage(initialOffer: offer),
      ),
    );
  }

  static Future<void> _openSettingsCameraPage(
    BuildContext context,
    CameraProgramFirmwareOffer offer,
  ) async {
    await Navigator.of(context, rootNavigator: true).pushNamed(
      AppRoutes.settings,
      arguments: SettingsRouteArgs(
        initialNestedPage: CameraProgramUpgradePage(initialOffer: offer),
      ),
    );
  }
}
