import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/app_typography.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

enum _CustomHomeSaveStatus { success, failure }

/// Custom Home save tip — green pass uses toast-like cream fill; failure uses
/// opaque charcoal (same family as Key switch is off).
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
  static const _titleSize = AppTypography.largeDialogTitleSize;
  static const _bodySize = AppTypography.dialogTitleSize;
  static const _confirmMinWidth = 500.0;
  static const _titleDark = Color(0xFF1A1A1A);
  static const _bodyDark = Color(0xCC1A1A1A);

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final success = status == _CustomHomeSaveStatus.success;
    final title = success ? 'Save Succeeded' : 'Save Failed';
    final message = success ? 'Done' : 'Please try again';
    final icon = success
        ? ProcessModeAssets.dialogSuccess
        : ProcessModeAssets.dialogError;
    final textColor = success ? _titleDark : CyberColors.textPrimary;
    final bodyColor = success ? _bodyDark : CyberColors.textPrimary;

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
            style: TextStyle(
              color: textColor,
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              letterSpacing: 0.02 * _titleSize,
              decoration: TextDecoration.none,
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
              style: TextStyle(
                color: bodyColor,
                fontSize: _bodySize,
                fontWeight: FontWeight.w400,
                height: 1.2,
                decoration: TextDecoration.none,
              ),
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
              child: SizedBox(
                width: double.infinity,
                child: _OrangePillButton(
                  label: 'OK',
                  onPressed: onConfirm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _OrangePillButton extends StatelessWidget {
  const _OrangePillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('custom-home-save-success-ok'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        CyberClickSoundRegistry.playClick();
        onPressed();
      },
      child: Container(
        height: CyberDimens.actionButtonSmallHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFF853E), Color(0xFFFF5C09)],
          ),
          border: Border.all(color: const Color(0xFFFFB070), width: 1.4),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF5C09), blurRadius: 12),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.dialogTitle.copyWith(
            color: Colors.white,
            height: 1,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
