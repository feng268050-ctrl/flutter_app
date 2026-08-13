import 'dart:async';

import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Informational Warn Frost prompt when the E-Stop button is pressed.
///
/// INFO chrome only — no warn-loop SFX (yellow warnings are silent).
/// Not a logged alarm. Once per E-stop press until the button releases.
abstract final class EmergencyStopPrompt {
  static bool _promptedForCurrentEStop = false;
  static bool _isShowing = false;
  static BuildContext? _dialogContext;

  static bool get isShowing => _isShowing;

  @visibleForTesting
  static bool get promptedForCurrentEStop => _promptedForCurrentEStop;

  static void reset() {
    _promptedForCurrentEStop = false;
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
    _isShowing = false;
  }

  /// Show when not yet latched for this E-stop press.
  static Future<void> maybeShow(BuildContext context) async {
    if (_promptedForCurrentEStop) {
      return;
    }
    _promptedForCurrentEStop = true;
    await _show(context);
  }

  /// Laser Enable blocked by E-stop: same Warn Frost tip as the safety edge.
  static Future<void> presentLaserEnableBlock(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    await maybeShow(context);
  }

  static Future<void> _show(BuildContext context) async {
    if (!context.mounted) {
      _promptedForCurrentEStop = false;
      return;
    }
    if (_isShowing) {
      return;
    }

    final scope =
        context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
    _isShowing = true;

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Emergency stop',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          _dialogContext = dialogContext;
          final l10n = AppLocalizations.of(dialogContext);
          return Material(
            type: MaterialType.transparency,
            key: const ValueKey('emergency-stop-prompt'),
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n?.emergencyStopAlarmTitle ??
                    'Emergency Stop Is Active',
                body: l10n != null
                    ? DeviceControlFeedbackCopy.emergencyStopError(l10n)
                    : 'The E-Stop button is pressed. Rotate the button in the '
                        'direction of the arrow until it releases, then try '
                        'again.',
                confirmLabel: l10n?.confirmText ?? 'Confirm',
                infoStyle: true,
                onConfirm: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
          );
        },
      );
    } finally {
      _dialogContext = null;
      _isShowing = false;
      _promptedForCurrentEStop = false;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _promptedForCurrentEStop = false;
    _dialogContext = null;
    _isShowing = false;
  }
}
