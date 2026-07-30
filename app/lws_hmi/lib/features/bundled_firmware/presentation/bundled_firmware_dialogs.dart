import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Confirm / progress / result dialogs for bundled control-board firmware.
///
/// Uses standard [CyberOverlayHost] + [CyberPromptContent] chrome.
abstract final class BundledFirmwareDialogs {
  static Future<bool> showConfirm({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
  }) async {
    final result = await CyberOverlayHost.show<bool>(
      context: context,
      barrierDismissible: true,
      freezePageBackdrop: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return CyberPromptContent(
          title: l10n.bundledFirmwareDialogTitle,
          body: Text(
            l10n.bundledFirmwareDialogMessage(currentVersion, newVersion),
          ),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelText),
            ),
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.okText),
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
    CyberOverlayHost.show<void>(
      context: context,
      barrierDismissible: false,
      freezePageBackdrop: false,
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
    return _showResult(
      context: context,
      title: (l10n) => l10n.bundledFirmwareSuccessTitle,
      message: (l10n) => l10n.bundledFirmwareSuccessMessage,
    );
  }

  static Future<void> showFailed(BuildContext context) {
    return _showResult(
      context: context,
      title: (l10n) => l10n.bundledFirmwareFailedTitle,
      message: (l10n) => l10n.bundledFirmwareFailedMessage,
    );
  }

  static Future<void> _showResult({
    required BuildContext context,
    required String Function(AppLocalizations) title,
    required String Function(AppLocalizations) message,
  }) {
    return CyberOverlayHost.show<void>(
      context: context,
      freezePageBackdrop: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return CyberPromptContent(
          title: title(l10n),
          body: Text(message(l10n)),
          actions: [
            CyberButton(
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.okText),
            ),
          ],
        );
      },
    );
  }
}
