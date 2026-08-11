import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/theme/hmi_typography.dart';
import 'package:lws_hmi/ui/hmi/hmi_button.dart';
import 'package:lws_hmi/app/theme/hmi_button_metrics.dart';
import 'package:lws_hmi/features/process_mode/application/device_control_controller.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/domain/process_mode_assets.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';
import 'package:lws_hmi/ui/tip_dialog_host.dart';

/// lws-ui [FrostStatusDialog] failure / tip mode (`OperationDialogBuilder.openErrorDialog`).
///
/// Panel chrome matches pass tips ([TipDialogHost.showSuccess]) — LIGHT cream
/// glass with baked blur; only the error icon and copy differ.
/// Key-off / E-stop tips auto-dismiss when the safety edge clears (warn-style
/// falling → dismiss), unless the operator already closed them.
abstract final class OperationFailedDialogHost {
  static bool _showing = false;
  static BuildContext? _dialogContext;

  /// Which safety tip is open (`emergencyStop` / `keySwitchOff`), or null for
  /// generic Operation-failed tips (laser preflight, etc.).
  static DeviceControlSafetyEvent? _shownFor;

  @visibleForTesting
  static bool get isShowing => _showing;

  @visibleForTesting
  static DeviceControlSafetyEvent? get shownFor => _shownFor;

  @visibleForTesting
  static void debugReset() {
    _showing = false;
    _dialogContext = null;
    _shownFor = null;
  }

  /// Shows once; no-ops while another Operation-failed tip is open.
  ///
  /// Pass [safetyEvent] for key-off / e-stop so [dismissForSafetyClear] can
  /// match the tip that should auto-exit on restore.
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? title,
    DeviceControlSafetyEvent? safetyEvent,
  }) async {
    if (_showing || !context.mounted) {
      return;
    }
    _showing = true;
    _shownFor = safetyEvent;
    try {
      final l10n = AppLocalizations.of(context)!;
      await showOperationFailedDialog(
        context,
        title: title ?? DeviceControlFeedbackCopy.operationFailedTitle(l10n),
        message: message,
        onDialogContext: (dialogContext) {
          _dialogContext = dialogContext;
        },
      );
    } finally {
      _dialogContext = null;
      _shownFor = null;
      _showing = false;
    }
  }

  /// Auto-dismiss open tip when e-stop releases or key returns ON.
  ///
  /// Mirrors warn frost falling → [WarnPresentation.dismiss]: only the matching
  /// tip closes; generic Operation-failed tips are left alone.
  static void dismissForSafetyClear(DeviceControlSafetyEvent clearEvent) {
    final expected = switch (clearEvent) {
      DeviceControlSafetyEvent.emergencyStopCleared =>
        DeviceControlSafetyEvent.emergencyStop,
      DeviceControlSafetyEvent.keySwitchRestored =>
        DeviceControlSafetyEvent.keySwitchOff,
      _ => null,
    };
    if (expected == null || _shownFor != expected) {
      return;
    }
    dismissIfShowing();
  }

  static void dismissIfShowing() {
    final dialogContext = _dialogContext;
    _dialogContext = null;
    if (dialogContext != null && dialogContext.mounted) {
      final nav = Navigator.of(dialogContext, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }
    }
  }
}

Future<void> showOperationFailedDialog(
  BuildContext context, {
  required String message,
  String? title,
  void Function(BuildContext dialogContext)? onDialogContext,
}) {
  final l10n = AppLocalizations.of(context)!;
  return TipDialogHost.showError<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      onDialogContext?.call(dialogContext);
      return _OperationFailedBody(
        title: title ?? DeviceControlFeedbackCopy.operationFailedTitle(l10n),
        message: message,
        onConfirm: () => Navigator.of(dialogContext).pop(),
      );
    },
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

  /// Dark ink on cream status tips (`dialog_frost_body_status`).
  static const _titleInk = Color(0xFF1A1A1A);
  static const _bodyInk = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.62).clamp(320.0, _maxWidth);
    final titleStyle = context.hmiTypography.importantDialogTitle.copyWith(
      color: _titleInk,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing:
          0.02 * (context.hmiTypography.importantDialogTitle.fontSize ?? 0),
      decoration: TextDecoration.none,
    );
    final bodyStyle = context.hmiTypography.importantDialogBody.copyWith(
      color: _bodyInk,
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
          const TipFrostDivider(),
          const SizedBox(height: CyberDimens.contentPadding),
          Center(
            child: Image(
              image: const AssetImage(ProcessModeAssets.dialogError),
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
          const TipFrostDivider(),
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
