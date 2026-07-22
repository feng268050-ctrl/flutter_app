import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cyber_alarm/src/catalog/alarm_code_catalog.dart';
import 'package:cyber_alarm/src/domain/alarm_signal_event.dart';
import 'package:cyber_alarm/src/domain/warn_episode.dart';
import 'package:cyber_alarm/src/domain/warn_episode_policy.dart';
import 'package:cyber_alarm/src/ports/alarm_log_repository.dart';
import 'package:cyber_alarm/src/ports/alarm_signal_source.dart';
import 'package:cyber_alarm/src/ports/warn_gate.dart';
import 'package:cyber_alarm/src/ports/warn_presentation.dart';

// #region agent log
void _warnDbg(String hypothesisId, String location, String message,
    [Map<String, Object?> data = const {}]) {
  // Package cannot import App logger; print NDJSON for journal + board scrape.
  // ignore: avoid_print
  print(
    'WARN_DBG ${jsonEncode({
      'sessionId': '438915',
      'timestamp': DateTime.now().toUtc().millisecondsSinceEpoch,
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'runId': 'pre',
      'data': data,
    })}',
  );
}
// #endregion

/// Arms episodes from [AlarmSignalSource], queues presentation, writes history.
final class WarnAlarmCoordinator {
  WarnAlarmCoordinator({
    required this.catalog,
    required this.signals,
    required this.presentation,
    required this.log,
    WarnGate? gate,
    this.policyForCode,
    this.now,
  }) : gate = gate ?? const AllowWarnGate();

  final AlarmCodeCatalog catalog;
  final AlarmSignalSource signals;
  final WarnPresentation presentation;
  final AlarmLogRepository log;
  final WarnGate gate;

  /// Override policy per code; default [WarnEpisodePolicy.productionPassive].
  final WarnEpisodePolicy Function(String code)? policyForCode;

  /// Test clock.
  final DateTime Function()? now;

  final Map<String, WarnEpisode> _episodes = {};
  final Queue<String> _showQueue = Queue<String>();
  String? _showingCode;
  StreamSubscription<AlarmSignalEvent>? _sub;
  bool _started = false;

  /// Serializes [_pumpQueue] so dialog close + rising edges cannot drain the
  /// queue concurrently (which dropped follow-up codes like C002).
  Future<void> _pumpTail = Future<void>.value();

  Map<String, WarnEpisode> get episodes =>
      Map<String, WarnEpisode>.unmodifiable(_episodes);

  String? get showingCode => _showingCode;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _sub = signals.events.listen(_onEvent);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  Future<void> dispose() => stop();

  /// Operator confirmed the visible / coded warn.
  Future<void> acknowledgeOperator(String code) async {
    final ep = _episodes[code];
    if (ep == null) {
      return;
    }
    ep.phase = WarnEpisodePhase.operatorAcked;
    if (!ep.faultActive) {
      await _teardown(code);
    } else {
      await presentation.dismiss(code);
      ep.dialogOpen = false;
      if (_showingCode == code) {
        _showingCode = null;
      }
      // Do not pump here — [onPresentationClosed] / in-flight drain continues
      // the queue. Concurrent pump raced and skipped follow-up dialogs.
    }
  }

  /// Staging/debug: arm a demo episode ([WarnEpisodePolicy.demoAlarm]).
  ///
  /// Mirrors lws-ui `WarnEpisodeController.armDemoEpisode`. Unknown catalog
  /// codes are rejected (no soft-fail placeholder).
  Future<void> armDemoEpisode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || !catalog.contains(trimmed)) {
      return;
    }
    await _onRising(
      AlarmSignalEvent(
        code: trimmed,
        active: true,
        kind: AlarmSignalKind.rising,
      ),
      policyOverride: WarnEpisodePolicy.demoAlarm,
    );
  }

  /// Staging/debug: clear episode restrictions without dismissing a visible warn.
  ///
  /// Cancels queued (not yet shown) warns. Mirrors lws-ui `clearAllForDebug`.
  Future<void> clearAllForDebug() async {
    _showQueue.clear();
    _episodes.clear();
    // Keep [_showingCode] / open overlay; Confirm still closes UI via presentation.
  }

  Future<void> _onEvent(AlarmSignalEvent event) async {
    switch (event.kind) {
      case AlarmSignalKind.rising:
        await _onRising(event);
      case AlarmSignalKind.falling:
        await _onFalling(event);
      case AlarmSignalKind.reminder:
        await _onReminder(event);
    }
  }

  Future<void> _onRising(
    AlarmSignalEvent event, {
    WarnEpisodePolicy? policyOverride,
  }) async {
    final code = event.code;
    if (code.isEmpty) {
      return;
    }
    // #region agent log
    _warnDbg('C', 'warn_alarm_coordinator.dart:_onRising', 'rising', {
      'code': code,
      'gateSuppressed': gate.isPresentationSuppressed,
      'existing': _episodes[code]?.faultActive == true,
      'demo': policyOverride?.demoSimulated == true,
    });
    // #endregion
    final entry = catalog.resolve(code, labelHint: event.labelHint);
    final policy = policyOverride ??
        policyForCode?.call(code) ??
        WarnEpisodePolicy.productionPassive;

    final existing = _episodes[code];
    if (existing != null && existing.faultActive) {
      // Already active — refresh phase for re-arm semantics.
      existing.phase = WarnEpisodePhase.faultActive;
      // If a prior rising was gated (no show yet), retry enqueue.
      if (!existing.dialogOpen && _showingCode != code) {
        _enqueueShow(code);
        await _pumpQueue();
      }
      return;
    }

    final episode = WarnEpisode(code: code, policy: policy);
    _episodes[code] = episode;

    try {
      await log.insertRising(
        AlarmLogEntry(
          code: code,
          title: entry.title,
          label: entry.displayLabel,
          timestamp: (now ?? DateTime.now)().toUtc(),
        ),
      );
    } catch (e) {
      // History is best-effort; presentation must still proceed.
      _warnDbg('C', 'warn_alarm_coordinator.dart:_onRising', 'insertRising failed', {
        'code': code,
        'error': e.toString(),
      });
    }

    // Always enqueue; [_pumpQueue] parks while [gate] suppresses presentation.
    _enqueueShow(code);
    await _pumpQueue();
  }

  Future<void> _onFalling(AlarmSignalEvent event) async {
    final code = event.code;
    final ep = _episodes[code];
    if (ep == null) {
      return;
    }
    ep.faultActive = false;
    if (ep.policy.resistExternalAutoClose &&
        ep.phase != WarnEpisodePhase.operatorAcked) {
      // Keep episode until operator ack.
      return;
    }
    await _teardown(code);
  }

  Future<void> _onReminder(AlarmSignalEvent event) async {
    final code = event.code;
    final ep = _episodes[code];
    if (ep == null || !ep.faultActive) {
      return;
    }
    if (gate.isPresentationSuppressed) {
      return;
    }
    final entry = catalog.resolve(code, labelHint: event.labelHint);
    if (ep.dialogOpen || _showingCode == code) {
      await presentation.update(ep, entry);
      return;
    }
    if (ep.phase == WarnEpisodePhase.operatorAcked) {
      ep.phase = WarnEpisodePhase.faultActive;
    }
    _enqueueShow(code);
    await _pumpQueue();
  }

  void _enqueueShow(String code) {
    if (_showQueue.contains(code) || _showingCode == code) {
      return;
    }
    _showQueue.addLast(code);
  }

  /// Drains the show queue. Calls are serialized on [_pumpTail].
  Future<void> _pumpQueue() {
    _pumpTail = _pumpTail.then((_) => _drainShowQueue()).catchError((Object e) {
      _warnDbg('D', 'warn_alarm_coordinator.dart:_pumpQueue', 'pump chain error', {
        'error': e.toString(),
      });
    });
    return _pumpTail;
  }

  Future<void> _drainShowQueue() async {
    while (_showQueue.isNotEmpty) {
      if (_showingCode != null) {
        // In-flight dialog owns the drain; a chained pump will run after.
        return;
      }
      final code = _showQueue.removeFirst();
      final ep = _episodes[code];
      if (ep == null || !ep.faultActive) {
        continue;
      }
      // After Confirm, stay silent until reminder / new rising re-arms phase.
      // (Demo used to re-show here and spam when flushPresentation ran.)
      if (ep.phase == WarnEpisodePhase.operatorAcked) {
        continue;
      }
      if (gate.isPresentationSuppressed) {
        // #region agent log
        _warnDbg('C', 'warn_alarm_coordinator.dart:_pumpQueue', 'parked by gate', {
          'code': code,
        });
        // #endregion
        _showQueue.addFirst(code);
        return;
      }
      final entry = catalog.resolve(code);
      // #region agent log
      _warnDbg('D', 'warn_alarm_coordinator.dart:_pumpQueue', 'calling presentation.show', {
        'code': code,
      });
      // #endregion
      _showingCode = code;
      ep.dialogOpen = true;
      try {
        await presentation.show(ep, entry);
      } catch (e) {
        // #region agent log
        _warnDbg('D', 'warn_alarm_coordinator.dart:_pumpQueue', 'presentation.show threw', {
          'code': code,
          'error': e.toString(),
        });
        // #endregion
        ep.dialogOpen = false;
        if (_showingCode == code) {
          _showingCode = null;
        }
        _enqueueShow(code);
        // Brief backoff then chained retry via caller/flush; avoid tight loop.
        return;
      } finally {
        if (_showingCode == code) {
          _showingCode = null;
        }
        ep.dialogOpen = false;
      }
    }
  }

  /// Presentation host finished (dismissed / recovered).
  Future<void> onPresentationClosed(String code) async {
    final ep = _episodes[code];
    if (ep != null) {
      ep.dialogOpen = false;
    }
    if (_showingCode == code) {
      _showingCode = null;
    }
    await _pumpQueue();
  }

  /// Call when [WarnGate] becomes open (e.g. boot self-check finished).
  ///
  /// Re-queues fault-active episodes that never presented while gated, then pumps.
  Future<void> flushPresentation() async {
    for (final ep in _episodes.values) {
      if (!ep.faultActive) {
        continue;
      }
      if (ep.phase == WarnEpisodePhase.operatorAcked) {
        continue;
      }
      if (ep.dialogOpen || _showingCode == ep.code) {
        continue;
      }
      _enqueueShow(ep.code);
    }
    await _pumpQueue();
  }

  Future<void> _teardown(String code) async {
    _showQueue.removeWhere((c) => c == code);
    final ep = _episodes.remove(code);
    if (ep != null) {
      await presentation.dismiss(code);
    }
    if (_showingCode == code) {
      _showingCode = null;
    }
    await _pumpQueue();
  }
}
