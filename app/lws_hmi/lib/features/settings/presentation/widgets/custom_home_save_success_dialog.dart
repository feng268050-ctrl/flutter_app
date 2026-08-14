import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

enum _CustomHomeSaveStatus { success, failure }

/// Custom Home save tip — dark frost like boot self-check (pass / fail icons).
Future<void> showCustomHomeSaveSuccessDialog(BuildContext context) =>
    _showCustomHomeSaveStatusDialog(
      context,
      status: _CustomHomeSaveStatus.success,
    );

Future<void> showCustomHomeSaveFailureDialog(BuildContext context) =>
    _showCustomHomeSaveStatusDialog(
      context,
      status: _CustomHomeSaveStatus.failure,
    );

Future<void> _showCustomHomeSaveStatusDialog(
  BuildContext context, {
  required _CustomHomeSaveStatus status,
}) async {
  Timer? autoDismissTimer;
  try {
    final show = status == _CustomHomeSaveStatus.success
        ? TipDialogHost.showSuccess<void>
        : TipDialogHost.showError<void>;
    await show(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (status == _CustomHomeSaveStatus.success &&
            autoDismissTimer == null) {
          autoDismissTimer = Timer(const Duration(milliseconds: 1500), () {
            if (dialogContext.mounted &&
                ModalRoute.of(dialogContext)?.isCurrent == true) {
              Navigator.of(dialogContext).pop();
            }
          });
        }
        return _CustomHomeSaveSuccessBody(
          status: status,
          onConfirm: () => Navigator.of(dialogContext).pop(),
        );
      },
    );
  } finally {
    autoDismissTimer?.cancel();
  }
}

/// Metrics match `dialog_frost_prompt` + `dialog_frost_body_status` (mode 1).
final class _CustomHomeSaveSuccessBody extends StatelessWidget {
  const _CustomHomeSaveSuccessBody({
    required this.status,
    required this.onConfirm,
  });

  final _CustomHomeSaveStatus status;
  final VoidCallback onConfirm;

  static const _maxWidth = 720.0;
  static const _iconSize = 80.0;
  static const _confirmMinWidth = 500.0;

  static const _titleInk = CyberColors.textPrimary;
  static const _bodyInk = CyberColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final success = status == _CustomHomeSaveStatus.success;
    // lws-ui `saved_successfully` / save-failed tip titles.
    final title = success ? l10n.savedSuccessfully : l10n.saveFailed;
    final message = success ? l10n.doneText : l10n.pleaseTryAgain;
    final icon = success
        ? ProcessModeAssets.dialogSuccess
        : ProcessModeAssets.dialogError;
    final titleStyle = context.hmiTypography.dialogTitle.copyWith(
      color: _titleInk,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0.02 * (context.hmiTypography.dialogTitle.fontSize ?? 0),
      decoration: TextDecoration.none,
    );
    final messageStyle = context.hmiTypography.dialogBody.copyWith(
      color: _bodyInk,
      fontWeight: FontWeight.w400,
      height: 1.2,
      decoration: TextDecoration.none,
    );

    return ConstrainedBox(
      key: const ValueKey('custom-home-save-success-dialog'),
      constraints: BoxConstraints(maxWidth: cardW),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const TipFrostDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: Image(
              image: AssetImage(icon),
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: messageStyle,
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const TipFrostDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: _confirmMinWidth.clamp(200.0, cardW),
                maxWidth: _confirmMinWidth.clamp(200.0, cardW),
              ),
              child: HmiButton(
                key: const ValueKey('custom-home-save-success-ok'),
                label: l10n.okText,
                size: HmiButtonSize.medium,
                widthPolicy: HmiButtonWidthPolicy.fill,
                variant: CyberButtonVariant.primary,
                shape: CyberButtonShape.rounded,
                onPressed: onConfirm,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
