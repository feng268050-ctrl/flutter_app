import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

enum _OtaCheckTipStatus { success, failure }

/// lws-ui Check-for-Updates status tip (`FrostStatusDialog` success / fail).
///
/// Uses [TipDialogHost.showSuccess] / [TipDialogHost.showError] (Startup
/// Self-Check dark frost) — same tip path as Custom Home save / Alarm Cleared.
Future<void> showOtaCheckUpToDateDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return _showOtaCheckStatusDialog(
    context,
    status: _OtaCheckTipStatus.success,
    title: l10n.otaCheckUpToDateTitle,
    message: l10n.otaAlreadyUpToDate,
  );
}

Future<void> showOtaCheckFailedDialog(
  BuildContext context, {
  required String message,
  String? title,
}) {
  final l10n = AppLocalizations.of(context)!;
  return _showOtaCheckStatusDialog(
    context,
    status: _OtaCheckTipStatus.failure,
    title: title ?? l10n.otaCheckFailedTitle,
    message: message,
  );
}

Future<void> _showOtaCheckStatusDialog(
  BuildContext context, {
  required _OtaCheckTipStatus status,
  required String title,
  required String message,
}) {
  final show = status == _OtaCheckTipStatus.success
      ? TipDialogHost.showSuccess<void>
      : TipDialogHost.showError<void>;
  return show(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _OtaCheckStatusBody(
      status: status,
      title: title,
      message: message,
      onConfirm: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

/// Metrics match `dialog_frost_prompt` + `dialog_frost_body_status`.
final class _OtaCheckStatusBody extends StatelessWidget {
  const _OtaCheckStatusBody({
    required this.status,
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final _OtaCheckTipStatus status;
  final String title;
  final String message;
  final VoidCallback onConfirm;

  static const _maxWidth = 720.0;
  static const _iconSize = 80.0;
  static const _confirmMinWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final success = status == _OtaCheckTipStatus.success;
    final icon = success
        ? ProcessModeAssets.dialogSuccess
        : ProcessModeAssets.dialogError;
    final titleStyle = context.hmiTypography.dialogTitle.copyWith(
      color: CyberColors.textPrimary,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: 0.02 * (context.hmiTypography.dialogTitle.fontSize ?? 0),
      decoration: TextDecoration.none,
    );
    final titleSize = titleStyle.fontSize ?? AppTypography.dialogTitleSize;
    final messageStyle = context.hmiTypography.body.copyWith(
      color: CyberColors.textSecondary,
      fontSize: AppTypography.tipBodySizeForTitle(titleSize),
      fontWeight: FontWeight.w400,
      height: 1.2,
      decoration: TextDecoration.none,
    );

    return ConstrainedBox(
      key: ValueKey(
        success ? 'ota-check-up-to-date-dialog' : 'ota-check-failed-dialog',
      ),
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
                key: ValueKey(
                  success ? 'ota-check-up-to-date-ok' : 'ota-check-failed-ok',
                ),
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
