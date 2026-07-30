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

/// Arms episodes from [AlarmSignalSource], requests presentation, writes history.
///
/// Modal FIFO is owned by the App global prompt queue via [presentation].
/// This coordinator only keeps a non-UI [_gateParked] set while [gate] suppresses.
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

  /// Codes that need show after [gate] opens (non-UI park).
  final LinkedHashSet<String> _gateParked = LinkedHashSet<String>();

  /// Codes with an in-flight or chained [presentation.show].
  final Set<String> _showRequested = <String>{};

  String? _showingCode;
  StreamSubscription<AlarmSignalEvent>? _sub;
  bool _started = false;

  /// Serializes [presentation.show] awaits (global queue still owns modal FIFO
  /// across warn + guidance; this only prevents overlapping show calls).
  Future<void> _presentChain = Future<void>.value();

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
      _showRequested.remove(code);
      if (_showingCode == code) {
        _showingCode = null;
      }
    }
  }

  /// lws-ui `WarnEpisodeController.requestImmediateShow` for Laser Enable
  /// preflight: re-open the blocking warn even after operator ack.
  Future<bool> requestImmediateShow(String code) async {
    final ep = _episodes[code];
    if (ep == null || !ep.faultActive) {
      return false;
    }
    if (_showingCode == code || ep.dialogOpen || _showRequested.contains(code)) {
      return true;
    }
    ep.phase = WarnEpisodePhase.faultActive;
    await _requestShow(code);
    return true;
  }

  /// Staging/debug: arm a demo episode ([WarnEpisodePolicy.demoAlarm]).
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
  Future<void> clearAllForDebug() async {
    _gateParked.clear();
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
    _warnDbg('C', 'warn_alarm_coordinator.dart:_onRising', 'rising', {
      'code': code,
      'gateSuppressed': gate.isPresentationSuppressed,
      'existing': _episodes[code]?.faultActive == true,
      'demo': policyOverride?.demoSimulated == true,
    });
    final entry = catalog.resolve(code, labelHint: event.labelHint);
    final policy = policyOverride ??
        policyForCode?.call(code) ??
        WarnEpisodePolicy.productionPassive;

    final existing = _episodes[code];
    if (existing != null && existing.faultActive) {
      existing.phase = WarnEpisodePhase.faultActive;
      if (!existing.dialogOpen &&
          _showingCode != code &&
          !_showRequested.contains(code)) {
        await _requestShow(code);
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
      _warnDbg('C', 'warn_alarm_coordinator.dart:_onRising', 'insertRising failed', {
        'code': code,
        'error': e.toString(),
      });
    }

    await _requestShow(code);
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
      _gateParked.add(code);
      return;
    }
    final entry = catalog.resolve(code, labelHint: event.labelHint);
    if (ep.dialogOpen || _showingCode == code || _showRequested.contains(code)) {
      await presentation.update(ep, entry);
      return;
    }
    if (ep.phase == WarnEpisodePhase.operatorAcked) {
      ep.phase = WarnEpisodePhase.faultActive;
    }
    await _requestShow(code);
  }

  Future<void> _requestShow(String code) async {
    if (gate.isPresentationSuppressed) {
      _warnDbg('C', 'warn_alarm_coordinator.dart:_requestShow', 'parked by gate', {
        'code': code,
      });
      _gateParked.add(code);
      return;
    }
    _gateParked.remove(code);

    final ep = _episodes[code];
    if (ep == null || !ep.faultActive) {
      return;
    }
    if (ep.phase == WarnEpisodePhase.operatorAcked) {
      return;
    }
    if (_showRequested.contains(code) ||
        ep.dialogOpen ||
        _showingCode == code) {
      return;
    }

    _showRequested.add(code);
    final done = Completer<void>();
    _presentChain = _presentChain.then((_) async {
      try {
        await _presentOne(code);
      } finally {
        _showRequested.remove(code);
        if (!done.isCompleted) {
          done.complete();
        }
      }
    }).catchError((Object e) {
      _warnDbg('D', 'warn_alarm_coordinator.dart:_requestShow', 'present chain error', {
        'code': code,
        'error': e.toString(),
      });
      _showRequested.remove(code);
      if (!done.isCompleted) {
        done.complete();
      }
    });
    await done.future;
  }

  Future<void> _presentOne(String code) async {
    final ep = _episodes[code];
    if (ep == null || !ep.faultActive) {
      return;
    }
    if (ep.phase == WarnEpisodePhase.operatorAcked) {
      return;
    }
    if (gate.isPresentationSuppressed) {
      _gateParked.add(code);
      return;
    }

    final entry = catalog.resolve(code);
    _warnDbg('D', 'warn_alarm_coordinator.dart:_presentOne', 'calling presentation.show', {
      'code': code,
    });
    _showingCode = code;
    ep.dialogOpen = true;
    try {
      await presentation.show(ep, entry);
    } catch (e) {
      _warnDbg('D', 'warn_alarm_coordinator.dart:_presentOne', 'presentation.show threw', {
        'code': code,
        'error': e.toString(),
      });
      if (ep.faultActive && ep.phase != WarnEpisodePhase.operatorAcked) {
        _gateParked.add(code);
      }
    } finally {
      ep.dialogOpen = false;
      if (_showingCode == code) {
        _showingCode = null;
      }
    }
  }

  /// Presentation host finished (dismissed / recovered).
  Future<void> onPresentationClosed(String code) async {
    final ep = _episodes[code];
    if (ep != null) {
      ep.dialogOpen = false;
    }
    _showRequested.remove(code);
    if (_showingCode == code) {
      _showingCode = null;
    }
  }

  /// Call when [WarnGate] becomes open (e.g. boot self-check finished).
  Future<void> flushPresentation() async {
    for (final ep in _episodes.values) {
      if (!ep.faultActive) {
        continue;
      }
      if (ep.phase == WarnEpisodePhase.operatorAcked) {
        continue;
      }
      if (ep.dialogOpen ||
          _showingCode == ep.code ||
          _showRequested.contains(ep.code)) {
        continue;
      }
      _gateParked.add(ep.code);
    }
    final parked = List<String>.from(_gateParked);
    _gateParked.clear();
    for (final code in parked) {
      // Fire without awaiting each — global prompt queue serializes modals.
      unawaited(_requestShow(code));
    }
  }

  Future<void> _teardown(String code) async {
    _gateParked.remove(code);
    final ep = _episodes.remove(code);
    if (ep != null) {
      await presentation.dismiss(code);
    }
    _showRequested.remove(code);
    if (_showingCode == code) {
      _showingCode = null;
    }
  }
}
