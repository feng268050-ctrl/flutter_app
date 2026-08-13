import 'dart:async';

import 'package:cyber_alarm_ui/cyber_alarm_ui.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/app/app_services.dart';
import 'package:lws_hmi/features/process_mode/domain/device_control_feedback_copy.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_sound.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Warn Frost for key-switch off: WARN (Misc alarm on) or INFO (Misc off).
///
/// Not a logged alarm. Edge latched once per key-off until key restore.
abstract final class KeySwitchOffPrompt {
  static const warnEpisodeCode = 'key_switch_off_prompt';

  static bool _promptedForCurrentKeyOff = false;
  static bool _isShowing = false;
  static BuildContext? _dialogContext;
  static WarnAlarmSound? _sound;
  static WarnChromeStyle? _showingChrome;

  static bool get isShowing => _isShowing;

  @visibleForTesting
  static bool get promptedForCurrentKeyOff => _promptedForCurrentKeyOff;

  @visibleForTesting
  static WarnChromeStyle? get showingChrome => _showingChrome;

  /// WARN when Misc Show Key Switch Alarm is on; INFO when off.
  @visibleForTesting
  static WarnChromeStyle chromeForMiscAlarmEnabled(bool miscAlarmEnabled) {
    return miscAlarmEnabled ? WarnChromeStyle.warn : WarnChromeStyle.info;
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
    _showingChrome = null;
    unawaited(_stopSound());
  }

  /// Physical key-off edge: WARN or INFO from Misc; latched until key restore.
  static Future<void> maybeShow(
    BuildContext context, {
    required bool miscAlarmEnabled,
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (_promptedForCurrentKeyOff) {
      return;
    }
    _promptedForCurrentKeyOff = true;
    await _show(
      context,
      chrome: chromeForMiscAlarmEnabled(miscAlarmEnabled),
      services: services,
      sound: sound,
    );
  }

  /// Laser Enable blocked with key off: always INFO (silent); replaces WARN if up.
  static Future<void> presentLaserEnableKeyOffBlock(
    BuildContext context, {
    AppServices? services,
    WarnAlarmSound? sound,
  }) async {
    if (!context.mounted) {
      return;
    }
    if (_isShowing) {
      dismissIfShowing();
    }
    await _show(
      context,
      chrome: WarnChromeStyle.info,
      services: services,
      sound: sound,
      ignoreEdgeLatch: true,
    );
  }

  static Future<void> _show(
    BuildContext context, {
    required WarnChromeStyle chrome,
    AppServices? services,
    WarnAlarmSound? sound,
    bool ignoreEdgeLatch = false,
  }) async {
    if (!context.mounted) {
      if (!ignoreEdgeLatch) {
        _promptedForCurrentKeyOff = false;
      }
      return;
    }
    if (_isShowing) {
      return;
    }

    final useSound = chrome == WarnChromeStyle.warn;
    if (useSound) {
      final resolvedServices = services ?? AppScope.maybeOf(context);
      _sound = sound ??
          (resolvedServices != null
              ? WarnAlarmSound(resolvedServices.audio)
              : null);
    } else {
      _sound = null;
    }

    final scope =
        context.findAncestorStateOfType<CyberBlurBackdropScopeState>();
    _isShowing = true;
    _showingChrome = chrome;
    if (useSound) {
      unawaited(_sound?.ensurePlaying(warnEpisodeCode));
    }

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
            key: ValueKey('key-switch-off-prompt-${chrome.name}'),
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n?.keySwitchOffAlarmTitle ?? 'Key Switch Off',
                body: l10n != null
                    ? DeviceControlFeedbackCopy.keySwitchOffError(l10n)
                    : 'Key switch is off',
                confirmLabel: l10n?.confirmText ?? 'Confirm',
                chromeStyle: chrome,
                beforeConfirm: useSound ? () => _stopSound() : null,
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
    _showingChrome = null;
    _sound = null;
  }
}
