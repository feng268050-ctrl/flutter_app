import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// lws-ui [FrostStatusDialog] failure / tip mode (`OperationDialogBuilder.openErrorDialog`).
///
/// Singleton-guarded so key-switch + e-stop paths cannot stack dialogs.
/// Chrome: opaque charcoal fill (no page透视) — red error tip preset.
abstract final class OperationFailedDialogHost {
  static bool _showing = false;

  @visibleForTesting
  static bool get isShowing => _showing;

  @visibleForTesting
  static void debugReset() {
    _showing = false;
  }

  /// Shows once; no-ops while another Operation-failed tip is open.
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? title,
  }) async {
    if (_showing || !context.mounted) {
      return;
    }
    _showing = true;
    try {
      final l10n = AppLocalizations.of(context)!;
      await showOperationFailedDialog(
        context,
        title: title ?? DeviceControlFeedbackCopy.operationFailedTitle(l10n),
        message: message,
      );
    } finally {
      _showing = false;
    }
  }
}

Future<void> showOperationFailedDialog(
  BuildContext context, {
  required String message,
  String? title,
}) {
  final l10n = AppLocalizations.of(context)!;
  return TipDialogHost.showError<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _OperationFailedBody(
      title: title ?? DeviceControlFeedbackCopy.operationFailedTitle(l10n),
      message: message,
      onConfirm: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

final class _OperationFailedBody extends StatelessWidget {
  const _OperationFailedBody({
    required this.title,
    required this.message,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final VoidCallback onConfirm;

  /// lws-ui default prompt width ≈ screen × 0.62; host caps at 720.
  static const _maxWidth = 720.0;

  /// `dialog_frost_body_status` icon 80dp.
  static const _iconSize = 80.0;

  /// `frost_dialog_prompt_confirm_button_min_width` / entry confirm 500dp.
  static const _confirmMinWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final titleStyle = context.hmiTypography.importantDialogTitle.copyWith(
      color: CyberColors.textPrimary,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing:
          0.02 * (context.hmiTypography.importantDialogTitle.fontSize ?? 0),
      decoration: TextDecoration.none,
    );
    final bodyStyle = context.hmiTypography.body.copyWith(
      color: CyberColors.textPrimary,
      fontWeight: FontWeight.w400,
      height: 1.2,
      decoration: TextDecoration.none,
    );

    return ConstrainedBox(
      key: const ValueKey('operation-failed-dialog'),
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
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x0068686C),
                  CyberColors.dividerCenter,
                  Color(0x0068686C),
                ],
              ),
            ),
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const Center(
            child: Image(
              image: AssetImage(ProcessModeAssets.dialogError),
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
              style: bodyStyle,
            ),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x0068686C),
                  CyberColors.dividerCenter,
                  Color(0x0068686C),
                ],
              ),
            ),
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: _confirmMinWidth.clamp(200.0, cardW),
                maxWidth: _confirmMinWidth.clamp(200.0, cardW),
              ),
              child: HmiButton(
                key: const ValueKey('operation-failed-ok'),
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
