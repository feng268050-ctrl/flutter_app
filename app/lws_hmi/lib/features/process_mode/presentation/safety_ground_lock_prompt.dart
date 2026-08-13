import 'dart:async';

import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Warn Frost when Laser Enable is on, gun is pressed, and safety ground is
/// unlocked (lws-ui `SafetyGroundLockPrompt`).
///
/// WARN chrome + SFX. Not a logged alarm; does not change Laser Enable.
/// Once per gun press. Confirm dismisses frost + SFX only. Auto-dismisses
/// when Enable turns off, gun releases, or ground locks.
abstract final class SafetyGroundLockPrompt {
  static const warnEpisodeCode = 'safety_ground_lock_prompt';

  static bool _promptedForCurrentGunPress = false;
  static bool _isShowing = false;
  static BuildContext? _dialogContext;
  static WarnAlarmSound? _sound;
  static WarnChromeStyle? _showingChrome;

  static bool get isShowing => _isShowing;

  @visibleForTesting
  static bool get promptedForCurrentGunPress => _promptedForCurrentGunPress;

  @visibleForTesting
  static WarnChromeStyle? get showingChrome => _showingChrome;

  /// Eligibility (settings gate + Enable + gun + unlocked ground).
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
    _showingChrome = null;
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
      debugPrint('safety-ground-prompt: skip (Misc showGroundLockAlarm off)');
      return;
    }
    if (_promptedForCurrentGunPress) {
      debugPrint('safety-ground-prompt: skip (already latched this gun press)');
      return;
    }
    _promptedForCurrentGunPress = true;
    debugPrint('safety-ground-prompt: show');
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
    _showingChrome = WarnChromeStyle.warn;
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
            key: const ValueKey('safety-ground-lock-prompt-warn'),
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n?.safetyGroundLockNotConnectedTitle ??
                    'Safety Clamp Disconnected',
                body: l10n?.safetyGroundLockNotConnectedMessage ??
                    'Connect the safety clamp before enabling the laser.',
                confirmLabel: l10n?.confirmText ?? 'Confirm',
                chromeStyle: WarnChromeStyle.warn,
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
      _showingChrome = null;
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
    _showingChrome = null;
    _sound = null;
  }
}
