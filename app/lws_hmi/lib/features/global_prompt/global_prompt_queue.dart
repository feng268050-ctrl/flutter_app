import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

/// Host passed to a prompt [present] callback while that entry is showing.
final class GlobalPromptHost {
  GlobalPromptHost({
    required this.context,
    required this.id,
    required void Function() requestClose,
    required void Function() markClosed,
  })  : _requestClose = requestClose,
        _markClosed = markClosed;

  final BuildContext context;
  final String id;
  final void Function() _requestClose;
  final void Function() _markClosed;

  /// Programmatic close of the visible prompt (pops the modal route).
  void close() => _requestClose();

  /// Call when the presenter has already removed its modal route (e.g. Confirm
  /// [Navigator.pop]) so a later [GlobalPromptQueue.dismiss] does not pop the
  /// underlying page.
  void markClosed() => _markClosed();
}

/// Process-wide FIFO prompt modal host (guidance + warn frost).
///
/// At most one prompt is visible. [enqueue] completes when **that** entry has
/// been presented and closed. [dismiss] drops a pending entry or closes the
/// visible modal when [id] matches.
final class GlobalPromptQueue {
  GlobalPromptQueue({
    required GlobalKey<NavigatorState> navigatorKey,
    bool Function()? isPumpSuppressed,
  })  : _navigatorKey = navigatorKey,
        _isPumpSuppressed = isPumpSuppressed ?? _neverSuppressed;

  static bool _neverSuppressed() => false;

  final GlobalKey<NavigatorState> _navigatorKey;
  final bool Function() _isPumpSuppressed;

  final Queue<_PendingPrompt> _queue = Queue<_PendingPrompt>();
  String? _showingId;
  bool _dialogOpen = false;

  /// True while the presenter's modal route is still on the navigator.
  ///
  /// Cleared by [GlobalPromptHost.markClosed] / [GlobalPromptHost.close] so
  /// [dismiss] after a self-[Navigator.pop] cannot pop the page underneath
  /// (`canPop` stays true for pushed product routes).
  bool _modalRouteActive = false;
  Completer<void>? _showingCompleter;
  Future<void> _pumpTail = Future<void>.value();

  String? get showingId => _showingId;

  bool get isIdle => !_dialogOpen && _queue.isEmpty;

  /// Re-attempt pump after a suppress gate clears (e.g. boot self-check done).
  void notifyGateChanged() {
    unawaited(_pump());
  }

  /// Enqueue a prompt. Same [id] already pending → replace. Same [id] showing →
  /// await the in-flight dialog (no second modal).
  Future<void> enqueue({
    required String id,
    required Future<void> Function(GlobalPromptHost host) present,
  }) async {
    if (_showingId == id && _dialogOpen && _showingCompleter != null) {
      await _showingCompleter!.future;
      return;
    }

    final completer = Completer<void>();
    _queue.removeWhere((p) {
      if (p.id == id) {
        if (!p.completer.isCompleted) {
          p.completer.complete();
        }
        return true;
      }
      return false;
    });
    _queue.addLast(
      _PendingPrompt(id: id, present: present, completer: completer),
    );
    await _pump();
    await completer.future;
  }

  Future<void> dismiss(String id) async {
    _queue.removeWhere((p) {
      if (p.id == id) {
        if (!p.completer.isCompleted) {
          p.completer.complete();
        }
        return true;
      }
      return false;
    });
    if (_showingId == id && _dialogOpen) {
      _popModalIfActive();
    }
  }

  void _popModalIfActive() {
    if (!_modalRouteActive) {
      return;
    }
    _modalRouteActive = false;
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    }
  }

  Future<void> _pump() {
    _pumpTail = _pumpTail.then((_) => _drain()).catchError((Object e) {
      debugPrint('global-prompt: pump error: $e');
    });
    return _pumpTail;
  }

  Future<void> _drain() async {
    if (_dialogOpen) {
      return;
    }
    if (_isPumpSuppressed()) {
      return;
    }
    if (_queue.isEmpty) {
      return;
    }

    final ctx = await _waitForContext();
    if (ctx == null || !ctx.mounted || _queue.isEmpty) {
      while (_queue.isNotEmpty) {
        final p = _queue.removeFirst();
        if (!p.completer.isCompleted) {
          p.completer.completeError(
            StateError('global prompt: navigator not ready'),
          );
        }
      }
      return;
    }
    if (_isPumpSuppressed() || _dialogOpen) {
      return;
    }

    final pending = _queue.removeFirst();
    final showingCompleter = Completer<void>();
    _showingId = pending.id;
    _dialogOpen = true;
    _modalRouteActive = true;
    _showingCompleter = showingCompleter;

    final host = GlobalPromptHost(
      context: ctx,
      id: pending.id,
      requestClose: _popModalIfActive,
      markClosed: () {
        _modalRouteActive = false;
      },
    );

    try {
      await pending.present(host);
    } catch (e, st) {
      debugPrint('global-prompt: present failed id=${pending.id}: $e\n$st');
    } finally {
      _modalRouteActive = false;
      _dialogOpen = false;
      _showingId = null;
      _showingCompleter = null;
      if (!showingCompleter.isCompleted) {
        showingCompleter.complete();
      }
      if (!pending.completer.isCompleted) {
        pending.completer.complete();
      }
      unawaited(_pump());
    }
  }

  Future<BuildContext?> _waitForContext({
    int attempts = 20,
    Duration step = const Duration(milliseconds: 50),
  }) async {
    for (var i = 0; i < attempts; i++) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        return ctx;
      }
      await Future<void>.delayed(step);
    }
    return _navigatorKey.currentContext;
  }
}

final class _PendingPrompt {
  _PendingPrompt({
    required this.id,
    required this.present,
    required this.completer,
  });

  final String id;
  final Future<void> Function(GlobalPromptHost host) present;
  final Completer<void> completer;
}
