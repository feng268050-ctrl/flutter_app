import 'dart:async';

import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_frost_shell.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Informational Frost prompt when Laser Enable is on, gun is pressed, and
/// safety ground is unlocked (lws-ui `SafetyGroundLockPrompt`).
///
/// Not a logged alarm. Once per gun press; auto-dismisses when Enable turns
/// off, gun releases, or ground locks.
abstract final class SafetyGroundLockPrompt {
  static const warnEpisodeCode = 'safety_ground_lock_prompt';

  static bool _promptedForCurrentGunPress = false;
  static bool _isShowing = false;
  static BuildContext? _dialogContext;
  static WarnAlarmSound? _sound;

  static bool get isShowing => _isShowing;

  @visibleForTesting
  static bool get promptedForCurrentGunPress => _promptedForCurrentGunPress;

  /// Eligibility (settings gate + Enable + gun + unlocked ground).
  @visibleForTesting
  static bool isEligibleForPrompt({
    required bool laserEnableActive,
    required bool gunSwitchOn,
    required bool safetyGroundLocked,
    required bool alarmEnabled,
  }) {
    if (!laserEnableActive || !alarmEnabled) {
      return false;
    }
    if (!gunSwitchOn) {
      return false;
    }
    return !safetyGroundLocked;
  }

  static void reset() {
    _promptedForCurrentGunPress = false;
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

  /// Show when eligible and not yet latched for this gun press.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool laserEnableActive,
    required bool gunSwitchOn,
    required bool safetyGroundLocked,
    required bool alarmEnabled,
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (!laserEnableActive) {
      reset();
      return;
    }
    if (!gunSwitchOn) {
      reset();
      return;
    }
    if (safetyGroundLocked) {
      reset();
      return;
    }
    if (!alarmEnabled) {
      return;
    }
    if (_promptedForCurrentGunPress) {
      return;
    }
    _promptedForCurrentGunPress = true;
    await _show(context, services: services, sound: sound);
  }

  static Future<void> _show(
    BuildContext context, {
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (!context.mounted) {
      _promptedForCurrentGunPress = false;
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
        barrierLabel: 'Safety ground lock',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          _dialogContext = dialogContext;
          final l10n = AppLocalizations.of(dialogContext);
          return Material(
            type: MaterialType.transparency,
            key: const ValueKey('safety-ground-lock-prompt'),
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n?.safetyGroundLockNotConnectedTitle ??
                    'Safety Clamp Disconnected',
                body: l10n?.connectSafetyClampBeforeLaser ??
                    'Connect the safety clamp before enabling the laser.',
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
      _promptedForCurrentGunPress = false;
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
    _promptedForCurrentGunPress = false;
    _dialogContext = null;
    _isShowing = false;
    _sound = null;
  }
}
