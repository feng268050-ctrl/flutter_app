import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Shared body text for process-video confirm prompts (lws-ui frost dialog).
const TextStyle _kPromptBodyStyle = TextStyle(
  color: CyberColors.textPrimary,
  fontSize: 18,
  height: 1.45,
  fontWeight: FontWeight.w400,
  decoration: TextDecoration.none,
);

Future<bool> _showProcessVideoPrompt({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await CyberOverlayHost.show<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0x99000000),
    freezePageBackdrop: false,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return CyberPromptContent(
        title: title,
        body: Text(
          message,
          textAlign: TextAlign.start,
          style: _kPromptBodyStyle,
        ),
        actions: [
          SizedBox(
            width: 168,
            child: CyberButton(
              size: CyberButtonSize.medium,
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
              stretch: true,
              variant: CyberButtonVariant.primary,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// lws-ui process-video delete confirm (Cancel / Delete).
Future<bool> showProcessVideoDeleteDialog({
  required BuildContext context,
}) {
  final l10n = AppLocalizations.of(context)!;
  return _showProcessVideoPrompt(
    context: context,
    title: l10n.processVideoDeleteConfirmTitle,
    message: l10n.processVideoDeleteConfirmMessage,
    confirmLabel: l10n.deleteText,
  );
}

/// lws-ui process-video upload confirm (Cancel / Upload).
///
/// Upload pipeline is not wired yet — callers should treat confirm as UI-only.
Future<bool> showProcessVideoUploadDialog({
  required BuildContext context,
}) {
  final l10n = AppLocalizations.of(context)!;
  return _showProcessVideoPrompt(
    context: context,
    title: l10n.processVideoUploadConfirmTitle,
    message: l10n.processVideoUploadConfirmMessage,
    confirmLabel: l10n.uploadText,
  );
}
