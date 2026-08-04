import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Confirm / progress / result dialogs for bundled control-board firmware.
///
/// Confirm/progress use Startup Self-Check frost; success = cream pass tip;
/// failure = charcoal error tip.
abstract final class BundledFirmwareDialogs {
  static Future<bool> showConfirm({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
  }) async {
    final result = await TipDialogHost.showDarkPrompt<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return CyberPromptContent(
          title: l10n.bundledFirmwareDialogTitle,
          body: Text(
            l10n.bundledFirmwareDialogMessage(currentVersion, newVersion),
          ),
          actions: [
            HmiButton(
              label: l10n.cancelText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            HmiButton(
              label: l10n.okText,
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

  /// Shows a non-dismissible progress dialog; returns a closer that pops it.
  static Future<void> Function() showProgress({
    required BuildContext context,
    required ValueListenable<int> percent,
  }) {
    TipDialogHost.showDarkPrompt<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return PopScope(
          canPop: false,
          child: CyberPromptContent(
            title: l10n.bundledFirmwareUpgradingTitle,
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.bundledFirmwareUpgradingMessage),
                const SizedBox(height: 20),
                ValueListenableBuilder<int>(
                  valueListenable: percent,
                  builder: (_, p, __) {
                    final clamped = p.clamp(0, 100);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LinearProgressIndicator(
                          value: clamped / 100.0,
                          minHeight: 8,
                          backgroundColor:
                              CyberColors.textSecondary.withOpacity(0.25),
                          color: CyberColors.textPrimary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.bundledFirmwareProgressPercent(clamped),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CyberColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    return () async {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }

  static Future<void> showSuccess(BuildContext context) {
    return TipDialogHost.showSuccess<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return CyberPromptContent(
          tone: CyberTone.light,
          title: l10n.bundledFirmwareSuccessTitle,
          body: Text(l10n.bundledFirmwareSuccessMessage),
          actions: [
            HmiButton(
              label: l10n.okText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  static Future<void> showFailed(BuildContext context) {
    return TipDialogHost.showError<void>(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return CyberPromptContent(
          title: l10n.bundledFirmwareFailedTitle,
          body: Text(l10n.bundledFirmwareFailedMessage),
          actions: [
            HmiButton(
              label: l10n.okText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }
}
