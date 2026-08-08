import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// lws-ui [FrostStatusDialog] success mode (`OperationDialogBuilder.openSuccessDialog`).
///
/// Title + success glyph + message + OK — toast-like cream fill (no page透视),
/// with title / body / action dividers like `dialog_frost_prompt`.
Future<void> showEngineerOperationSuccessDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
}) {
  return TipDialogHost.showSuccess<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _EngineerOperationSuccessBody(
      title: title,
      message: message,
      onConfirm: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

final class _EngineerOperationSuccessBody extends StatelessWidget {
  const _EngineerOperationSuccessBody({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;

  static const _maxWidth = 560.0;
  static const _iconSize = 80.0;
  static const _bodyDark = Color(0xFF1A1A1A);
  static const _titleDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = context.hmiTypography.dialogTitle.copyWith(
      color: _titleDark,
      fontWeight: FontWeight.w700,
      height: 1.15,
      decoration: TextDecoration.none,
    );
    final bodyStyle = context.hmiTypography.dialogBody.copyWith(
      color: _bodyDark,
      fontWeight: FontWeight.w400,
      height: 1.35,
      decoration: TextDecoration.none,
    );
    return ConstrainedBox(
      key: const ValueKey('engineer-operation-success'),
      constraints: const BoxConstraints(maxWidth: _maxWidth),
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
          const Center(
            child: Image(
              image: AssetImage('assets/process/dialog_succd.webp'),
              width: _iconSize,
              height: _iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: bodyStyle,
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const TipFrostDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: HmiButton(
                key: const ValueKey('engineer-operation-success-ok'),
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
