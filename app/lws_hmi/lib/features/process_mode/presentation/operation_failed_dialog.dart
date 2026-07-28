import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';

/// lws-ui [FrostStatusDialog] failure / tip mode (`OperationDialogBuilder.openErrorDialog`).
///
/// Singleton-guarded so key-switch + e-stop paths cannot stack dialogs.
/// Always a solid cream panel — **no** Gaussian / BackdropFilter (Weston).
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
    String title = DeviceControlFeedbackCopy.operationFailedTitle,
  }) async {
    if (_showing || !context.mounted) {
      return;
    }
    _showing = true;
    try {
      await showOperationFailedDialog(
        context,
        title: title,
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
  String title = DeviceControlFeedbackCopy.operationFailedTitle,
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
    intensity: CyberBlurIntensity.transparent,
    builder: (dialogContext) => _OperationFailedBody(
      title: title,
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

  static const _maxWidth = 560.0;
  static const _iconSize = 80.0;
  static const _titleSize = 32.0;
  static const _bodySize = 20.0;
  static const _titleDark = Color(0xFF1A1A1A);
  static const _bodyDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('operation-failed-dialog'),
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
              image: AssetImage(ProcessModeAssets.dialogError),
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
                  key: const ValueKey('operation-failed-ok'),
                  variant: CyberButtonVariant.primary,
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
