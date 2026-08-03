import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
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
          SizedBox(
            width: 168,
            child: CyberButton(
              size: CyberButtonSize.small,
              shape: CyberButtonShape.rounded,
              stretch: true,
              variant: CyberButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancelText),
            ),
          ),
          SizedBox(
            width: 168,
            child: CyberButton(
              size: CyberButtonSize.small,
              shape: CyberButtonShape.rounded,
              stretch: true,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirmText),
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}
