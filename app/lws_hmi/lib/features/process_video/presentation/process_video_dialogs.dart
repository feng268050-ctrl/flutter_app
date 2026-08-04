import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_dialog_actions.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// Shared body text for process-video confirm prompts (lws-ui frost dialog).
/// Color/size come from [CyberPromptContent] DefaultTextStyle.

Future<bool> _showProcessVideoPrompt({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await TipDialogHost.showDarkPrompt<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return CyberPromptContent(
        title: title,
        body: Text(
          message,
          textAlign: TextAlign.start,
        ),
        actions: [
          HmiDialogActions(
            cancelLabel: l10n.cancelText,
            confirmLabel: confirmLabel,
            onCancel: () => Navigator.pop(ctx, false),
            onConfirm: () => Navigator.pop(ctx, true),
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
