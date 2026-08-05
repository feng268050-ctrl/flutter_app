import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Confirm leaving CNC running mode (lws-ui `CNCExitDialog`).
///
/// Frost matches Startup Self-Check via [TipDialogHost].
Future<bool> showCncExitDialog(BuildContext context) async {
  final result = await TipDialogHost.showDarkPrompt<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'CNC exit',
    constraints: const BoxConstraints(maxWidth: 640, maxHeight: 420),
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      return KeyedSubtree(
        key: const ValueKey('quick-mode-cnc-exit-dialog'),
        child: CyberPromptContent(
          title: l10n.exitCncModeConfirmTitle,
          actions: [
            HmiButton(
              key: const ValueKey('quick-mode-cnc-exit-cancel'),
              label: l10n.cancelText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            HmiButton(
              key: const ValueKey('quick-mode-cnc-exit-confirm'),
              label: l10n.confirmText,
              size: HmiButtonSize.medium,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}
