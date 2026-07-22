import 'dart:async';
import 'dart:collection';

import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_debug_log.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';

/// Process-wide CyberUI warn host (single modal at a time).
///
/// Confirm/dismiss notifies [onClosed]; [WarnAlarmController] stops SFX on
/// operator ack (and restarts if a later dialog is shown).
final class CyberUiWarnPresentation implements WarnPresentation {
  CyberUiWarnPresentation({
    required this.navigatorKey,
    this.onClosed,
    this.onPresented,
    this.stopWarnSound,
    this.infoStyleForCode,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  /// Notifies coordinator when a dialog finishes (dismiss / confirm).
  void Function(String code)? onClosed;

  /// Fires when a dialog is about to appear (start SFX with the popup).
  void Function(String code)? onPresented;

  /// Stops warn SFX before Confirm click (single remote session exclusion).
  Future<void> Function()? stopWarnSound;

  /// When true, dialog uses INFO (black) title — dangerous-ops bypass.
  bool Function(String code)? infoStyleForCode;

  final Queue<_PendingWarn> _queue = Queue<_PendingWarn>();
  String? _showingCode;
  bool _dialogOpen = false;

  String? get showingCode => _showingCode;

  @override
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry) async {
    // #region agent log
    WarnAlarmDebugLog.log(
      hypothesisId: 'D',
      location: 'cyber_ui_warn_presentation.dart:show',
      message: 'show requested',
      data: {
        'code': episode.code,
        'hasContext': navigatorKey.currentContext != null,
      },
    );
    // #endregion
    final completer = Completer<void>();
    _queue.removeWhere((p) {
      if (p.code == episode.code) {
        if (!p.completer.isCompleted) {
          p.completer.complete();
        }
        return true;
      }
      return false;
    });
    _queue.addLast(
      _PendingWarn(episode: episode, entry: entry, completer: completer),
    );
    await _pump();
    // Wait until *this* dialog has been presented and closed (not merely
    // queued behind an in-flight modal — that used to return immediately).
    await completer.future;
  }

  @override
  Future<void> dismiss(String code) async {
    _queue.removeWhere((p) {
      if (p.code == code) {
        if (!p.completer.isCompleted) {
          p.completer.complete();
        }
        return true;
      }
      return false;
    });
    if (_showingCode == code && _dialogOpen) {
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
  }

  @override
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry) async {
    if (_showingCode == episode.code) {
      return;
    }
    await show(episode, entry);
  }

  Future<BuildContext?> _waitForContext({
    int attempts = 20,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        return ctx;
      }
      await Future<void>.delayed(step);
    }
    return navigatorKey.currentContext;
  }

  Future<void> _pump() async {
    if (_dialogOpen) {
      return;
    }
    if (_queue.isEmpty) {
      return;
    }
    final ctx = await _waitForContext();
    if (ctx == null || !ctx.mounted || _queue.isEmpty) {
      // #region agent log
      WarnAlarmDebugLog.log(
        hypothesisId: 'D',
        location: 'cyber_ui_warn_presentation.dart:_pump',
        message: 'navigator not ready',
        data: {
          'ctxNull': ctx == null,
          'queueLen': _queue.length,
        },
      );
      // #endregion
      // Fail queued waiters so the coordinator can retry.
      while (_queue.isNotEmpty) {
        final p = _queue.removeFirst();
        if (!p.completer.isCompleted) {
          p.completer.completeError(
            StateError('warn presentation: navigator not ready'),
          );
        }
      }
      return;
    }
    final pending = _queue.removeFirst();
    // #region agent log
    WarnAlarmDebugLog.log(
      hypothesisId: 'D',
      location: 'cyber_ui_warn_presentation.dart:_pump',
      message: 'opening showCyberDialog',
      data: {'code': pending.code},
    );
    // #endregion
    _showingCode = pending.code;
    _dialogOpen = true;
    onPresented?.call(pending.code);
    try {
      // Light frost shell (lws-ui FrostPromptDialog) — fake cream glass on Weston.
      await CyberOverlayHost.show<void>(
        context: ctx,
        barrierDismissible: false,
        barrierColor: CyberColors.scrim,
        freezePageBackdrop: false,
        useFakeGlass: true,
        tone: CyberTone.light,
        blurTint: CyberBlurTint.warm,
        sampleMode: CyberBlurSampleMode.firstFrame,
        intensity: CyberBlurIntensity.high,
        builder: (dialogContext) {
          return WarnDialogBody(
            title: pending.entry.title,
            body: pending.entry.body,
            infoStyle: infoStyleForCode?.call(pending.code) ?? false,
            beforeConfirm: stopWarnSound,
            onConfirm: () {
              Navigator.of(dialogContext).pop();
            },
          );
        },
      );
    } finally {
      final closed = _showingCode;
      _dialogOpen = false;
      _showingCode = null;
      if (!pending.completer.isCompleted) {
        pending.completer.complete();
      }
      if (closed != null) {
        onClosed?.call(closed);
      }
      // Drain next after this dialog closes.
      unawaited(_pump());
    }
  }
}

final class _PendingWarn {
  _PendingWarn({
    required this.episode,
    required this.entry,
    required this.completer,
  });

  final WarnEpisode episode;
  final AlarmCodeEntry entry;
  final Completer<void> completer;

  String get code => episode.code;
}
