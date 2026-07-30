import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_models.dart';
import 'package:lws_hmi/features/statistics/domain/stats_aggregate_repository.dart';
import 'package:lws_hmi/features/statistics/infrastructure/sqlite_stats_aggregate_repository.dart';

/// Bridges one Laser Enable session to the single-row statistics aggregate.
///
/// Manual Feed/Retract never reaches this class. The caller supplies only the
/// applied process preset's automatic wire-feed speed before enabling laser.
final class WorkSessionStatisticsRecorder {
  WorkSessionStatisticsRecorder({StatsAggregateRepository? repository})
      : _repository = repository ?? SqliteStatsAggregateRepository();

  final StatsAggregateRepository _repository;
  WorkSessionStartEvent? _nextSession;

  void configureNextSession({
    required int modeType,
    required bool autoWireFeedEnabled,
    required double autoWireFeedSpeedMmPerSecond,
    int? materialType,
  }) {
    _nextSession = WorkSessionStartEvent(
      sessionId: _newSessionId(),
      modeType: modeType,
      autoWireFeedEnabled: autoWireFeedEnabled,
      autoWireFeedSpeedMmPerSecond: autoWireFeedSpeedMmPerSecond,
      materialType: materialType,
    );
  }

  Future<void> recordLaserEnabled() async {
    final session = _nextSession;
    if (session == null) {
      return;
    }
    try {
      await _repository.startWorkSession(session);
    } catch (error) {
      debugPrint('statistics: unable to start work session: $error');
    }
  }

  Future<void> settle() async {
    try {
      await _repository.settleActiveWorkSession();
    } catch (error) {
      debugPrint('statistics: unable to settle work session: $error');
    } finally {
      _nextSession = null;
    }
  }

  Future<void> dispose() => _repository.close();

  static String _newSessionId() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'work-$now-$random';
  }
}
