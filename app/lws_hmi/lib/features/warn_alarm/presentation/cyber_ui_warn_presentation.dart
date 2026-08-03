import 'package:cyber_alarm/cyber_alarm.dart';
import 'package:cyber_ui/cyber_ui.dart';
import 'package:flutter/material.dart';
import 'package:lws_hmi/features/global_prompt/global_prompt_queue.dart';
import 'package:lws_hmi/features/warn_alarm/infrastructure/warn_alarm_debug_log.dart';
import 'package:lws_hmi/features/warn_alarm/l10n/product_alarm_l10n.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_dialog_body.dart';
import 'package:lws_hmi/features/warn_alarm/presentation/warn_frost_shell.dart';
import 'package:lws_hmi/l10n/app_localizations.dart';

/// Warn frost host backed by [GlobalPromptQueue] (no private modal FIFO).
///
/// Confirm/dismiss notifies [onClosed]; [WarnAlarmController] stops SFX on
/// operator ack (and restarts if a later dialog is shown).
final class CyberUiWarnPresentation implements WarnPresentation {
  CyberUiWarnPresentation({
    required this.promptQueue,
    this.onClosed,
    this.onPresented,
    this.stopWarnSound,
    this.infoStyleForCode,
    this.bodyForCode,
  });

  final GlobalPromptQueue promptQueue;

  /// Notifies coordinator when a dialog finishes (dismiss / confirm).
  void Function(String code)? onClosed;

  /// Fires when a dialog is about to appear (start SFX with the popup).
  void Function(String code)? onPresented;

  /// Stops warn SFX before Confirm click (single remote session exclusion).
  Future<void> Function()? stopWarnSound;

  /// When true, dialog uses INFO (black) title — dangerous-ops bypass.
  bool Function(String code)? infoStyleForCode;

  /// Optional dynamic body (e.g. A001 cause list). Falls back to catalog l10n.
  String Function(String code, AppLocalizations l10n)? bodyForCode;

  String? _showingCode;

  String? get showingCode => _showingCode;

  @override
  Future<void> show(WarnEpisode episode, AlarmCodeEntry entry) async {
    WarnAlarmDebugLog.log(
      hypothesisId: 'D',
      location: 'cyber_ui_warn_presentation.dart:show',
      message: 'show requested',
      data: {'code': episode.code},
    );
    await promptQueue.enqueue(
      id: episode.code,
      present: (host) => _presentWarn(host, episode, entry),
    );
  }

  @override
  Future<void> dismiss(String code) async {
    // Confirm already cleared [_showingCode]; skip so ack → dismiss cannot
    // Navigator.pop the product page underneath the closed dialog.
    if (_showingCode != code) {
      return;
    }
    await promptQueue.dismiss(code);
  }

  @override
  Future<void> update(WarnEpisode episode, AlarmCodeEntry entry) async {
    if (_showingCode == episode.code || promptQueue.showingId == episode.code) {
      return;
    }
    await show(episode, entry);
  }

  Future<void> _presentWarn(
    GlobalPromptHost host,
    WarnEpisode episode,
    AlarmCodeEntry entry,
  ) async {
    final ctx = host.context;
    _showingCode = episode.code;
    onPresented?.call(episode.code);

    final scope = _findBlurScope(ctx);
    try {
      await showGeneralDialog<void>(
        context: ctx,
        barrierDismissible: false,
        barrierLabel: 'Warn ${episode.code}',
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          final l10n = AppLocalizations.of(dialogContext)!;
          return Material(
            type: MaterialType.transparency,
            child: WarnFrostShell(
              scope: scope,
              child: WarnDialogBody(
                title: l10n.alarmTitleFor(
                  episode.code,
                  fallback: entry.title,
                ),
                body: bodyForCode?.call(episode.code, l10n) ??
                    l10n.alarmBodyFor(
                      episode.code,
                      fallback: entry.body,
                    ),
                confirmLabel: l10n.confirmText,
                infoStyle: infoStyleForCode?.call(episode.code) ?? false,
                beforeConfirm: stopWarnSound,
                onConfirm: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
          );
        },
      );
    } finally {
      // Modal route is gone (Confirm / programmatic close). Mark before
      // [onClosed] → acknowledgeOperator → dismiss, which must not pop again.
      host.markClosed();
      final closed = _showingCode;
      _showingCode = null;
      if (closed != null) {
        onClosed?.call(closed);
      }
    }
  }
}

/// Nearest [CyberBlurBackdropScope] under [root] (active page), if any.
CyberBlurBackdropScopeState? _findBlurScope(BuildContext root) {
  CyberBlurBackdropScopeState? found;
  void visit(Element element) {
    if (found != null) {
      return;
    }
    if (element is StatefulElement &&
        element.state is CyberBlurBackdropScopeState) {
      found = element.state as CyberBlurBackdropScopeState;
      return;
    }
    element.visitChildren(visit);
  }

  root.visitChildElements(visit);
  return found;
}
