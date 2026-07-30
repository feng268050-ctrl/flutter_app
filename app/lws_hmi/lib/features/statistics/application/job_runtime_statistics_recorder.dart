import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';

/// Records confirmed foreground application runtime using elapsed wall time.
///
/// It deliberately does not invent a fixed 30/60-second increment: every
/// flush adds only the elapsed whole seconds since the prior checkpoint.
final class JobRuntimeStatisticsRecorder {
  JobRuntimeStatisticsRecorder({
    StatsAggregateRepository? repository,
    DateTime Function()? now,
    this.flushInterval = const Duration(seconds: 30),
  })  : _repository = repository ?? SqliteStatsAggregateRepository(),
        _now = now ?? DateTime.now;

  final StatsAggregateRepository _repository;
  final DateTime Function() _now;
  final Duration flushInterval;

  Timer? _timer;
  DateTime? _checkpoint;
  bool _disposed = false;

  void resume() {
    if (_disposed || _checkpoint != null) {
      return;
    }
    _checkpoint = _now();
    _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
    final checkpoint = _checkpoint;
    _checkpoint = null;
    if (checkpoint == null || _disposed) {
      return;
    }
    await _recordElapsed(checkpoint, _now());
  }

  Future<void> flush() async {
    final checkpoint = _checkpoint;
    if (_disposed || checkpoint == null) {
      return;
    }
    final current = _now();
    _checkpoint = current;
    await _recordElapsed(checkpoint, current);
  }

  Future<void> _recordElapsed(DateTime checkpoint, DateTime current) async {
    final elapsed = current.difference(checkpoint).inSeconds;
    // Clock rollback or an unreasonably long suspended interval is not a
    // trustworthy application-runtime observation, so drop that interval.
    if (elapsed <= 0 || elapsed > flushInterval.inSeconds * 3) {
      return;
    }
    try {
      await _repository.addJobRuntimeSeconds(elapsed);
    } catch (error) {
      debugPrint('statistics: unable to add job runtime: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    final checkpoint = _checkpoint;
    _checkpoint = null;
    if (checkpoint != null) {
      await _recordElapsed(checkpoint, _now());
    }
    _disposed = true;
    await _repository.close();
  }
}
