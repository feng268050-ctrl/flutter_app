import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';

/// lws-ui [FrostStatusDialog] success mode (`OperationDialogBuilder.openSuccessDialog`).
///
/// Title + success glyph + message + OK — light frost chrome (same family as
/// warn / engineer entry tips).
Future<void> showEngineerOperationSuccessDialog(
  BuildContext context, {
  required String message,
  String title = 'Success',
}) {
  return CyberOverlayHost.show<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: CyberColors.scrim,
    freezePageBackdrop: false,
    useFakeGlass: true,
    tone: CyberTone.light,
    blurTint: CyberBlurTint.warm,
    sampleMode: CyberBlurSampleMode.firstFrame,
    intensity: CyberBlurIntensity.high,
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
  static const _titleSize = 32.0;
  static const _bodySize = 20.0;
  static const _bodyDark = Color(0xFF1A1A1A);
  static const _titleDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              color: _titleDark,
              fontSize: _titleSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
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
            style: const TextStyle(
              color: _bodyDark,
              fontSize: _bodySize,
              fontWeight: FontWeight.w400,
              height: 1.35,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
              child: SizedBox(
                width: double.infinity,
                child: CyberButton(
                  key: const ValueKey('engineer-operation-success-ok'),
                  variant: CyberButtonVariant.primary,
                  shape: CyberButtonShape.rounded,
                  stretch: true,
                  height: CyberDimens.actionButtonHeight,
                  onPressed: () {
                    CyberClickSoundRegistry.playClick();
                    onConfirm();
                  },
                  child: const Text('OK'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
