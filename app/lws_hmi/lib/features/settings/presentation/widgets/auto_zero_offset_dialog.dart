import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// lws-ui Auto Zero Offset confirm prompt (UI only; AI procedure later).
Future<bool> showAutoZeroOffsetDialog({
  required BuildContext context,
}) async {
  final result = await CyberOverlayHost.show<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    freezePageBackdrop: false,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return CyberPromptContent(
        title: l10n.advancedSettingAutoZeroOffsetTitle,
        body: Text(
          l10n.advancedSettingAutoZeroOffsetMessage,
          textAlign: TextAlign.start,
          style: const TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 18,
            height: 1.45,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
        actions: [
          SizedBox(
            width: 168,
            child: CyberButton(
              size: CyberButtonSize.medium,
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
              size: CyberButtonSize.medium,
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
