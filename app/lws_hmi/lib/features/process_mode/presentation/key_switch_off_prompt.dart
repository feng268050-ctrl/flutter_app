import 'dart:async';

import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/process_mode/presentation/operation_failed_dialog.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Informational Frost prompt when the key switch turns off and the Misc
/// "Show Key Switch Alarm" preference is on (mirrors [SafetyGroundLockPrompt]).
///
/// Not a logged alarm. Once per key-off until the key is restored.
abstract final class KeySwitchOffPrompt {
  static const warnEpisodeCode = 'key_switch_off_prompt';

  static bool _promptedForCurrentKeyOff = false;
  static bool _isShowing = false;
  static BuildContext? _dialogContext;
  static WarnAlarmSound? _sound;

  static bool get isShowing => _isShowing;

  @visibleForTesting
  static bool get promptedForCurrentKeyOff => _promptedForCurrentKeyOff;

  /// Eligibility (Misc "Show Key Switch Alarm" gate only).
  @visibleForTesting
  static bool isEligibleForPrompt({required bool alarmEnabled}) {
    return alarmEnabled;
  }

  static void reset() {
    _promptedForCurrentKeyOff = false;
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
    unawaited(_stopSound());
  }

  /// Show when eligible and not yet latched for this key-off press.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool alarmEnabled,
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (!isEligibleForPrompt(alarmEnabled: alarmEnabled)) {
      return;
    }
    if (_promptedForCurrentKeyOff) {
      return;
    }
    _promptedForCurrentKeyOff = true;
    await _show(context, services: services, sound: sound);
  }

  /// Laser Enable blocked with key off: Misc alarm popup, else Operation-failed tip.
  static Future<void> presentLaserEnableKeyOffBlock(
    BuildContext context, {
    required bool miscAlarmEnabled,
    AppServices? services,
  }) async {
    if (!context.mounted) {
      return;
    }
    if (miscAlarmEnabled) {
      await maybeShow(
        context,
        alarmEnabled: true,
        services: services,
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await OperationFailedDialogHost.show(
      context,
      message: DeviceControlFeedbackCopy.keySwitchOffError(l10n),
    );
  }

  static Future<void> _show(
    BuildContext context, {
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (!context.mounted) {
      _promptedForCurrentKeyOff = false;
      return;
    }
    if (_isShowing) {
      return;
    }

    final resolvedServices = services ?? AppScope.maybeOf(context);
    _sound = sound ??
        (resolvedServices != null
            ? WarnAlarmSound(resolvedServices.audio)
            : null);

    final scope =
        context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
    _isShowing = true;
    unawaited(_sound?.ensurePlaying(warnEpisodeCode));

    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Key switch off',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          _dialogContext = dialogContext;
          final l10n = AppLocalizations.of(dialogContext);
          return Material(
            type: MaterialType.transparency,
            key: const ValueKey('key-switch-off-prompt'),
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n?.keySwitchOffAlarmTitle ?? 'Key Switch Off',
                body: l10n != null
                    ? DeviceControlFeedbackCopy.keySwitchOffError(l10n)
                    : 'Key switch is off',
                confirmLabel: l10n?.confirmText ?? 'Confirm',
                infoStyle: true,
                beforeConfirm: () => _stopSound(),
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
      _promptedForCurrentKeyOff = false;
      unawaited(_stopSound());
    }
  }

  static Future<void> _stopSound() async {
    final sound = _sound;
    _sound = null;
    await sound?.stopForEpisode(warnEpisodeCode);
  }

  @visibleForTesting
  static void debugReset() {
    _promptedForCurrentKeyOff = false;
    _dialogContext = null;
    _isShowing = false;
    _sound = null;
  }
}
