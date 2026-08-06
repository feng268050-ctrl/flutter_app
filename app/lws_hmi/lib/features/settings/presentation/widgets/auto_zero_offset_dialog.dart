import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_dialog_actions.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// lws-ui Auto Zero Offset confirm prompt (UI only; AI procedure later).
Future<bool> showAutoZeroOffsetDialog({
  required BuildContext context,
}) async {
  final result = await TipDialogHost.showDarkPrompt<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return CyberPromptContent(
        title: l10n.advancedSettingAutoZeroOffsetTitle,
        body: Text(
          l10n.advancedSettingAutoZeroOffsetMessage,
          textAlign: TextAlign.start,
        ),
        actions: [
          HmiDialogActions(
            cancelLabel: l10n.cancelText,
            confirmLabel: l10n.confirmText,
            onCancel: () => Navigator.pop(ctx, false),
            onConfirm: () => Navigator.pop(ctx, true),
          ),
        ],
      );
    },
  );
  return result == true;
}
