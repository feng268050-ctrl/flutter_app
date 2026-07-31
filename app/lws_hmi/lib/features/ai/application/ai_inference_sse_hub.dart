import 'dart:async';
import 'dart:convert';

import 'package:lws_hmi/features/ai/application/ai_inference_sse_json.dart';

/// Fan-out SSE for live camera AI (`GET /v1/camera/ai`).
///
/// Connection-relative [timestampMs]; idle every [idleInterval].
final class AiInferenceSseHub {
  AiInferenceSseHub({
    this.idleInterval = const Duration(seconds: 15),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration idleInterval;
  final DateTime Function() _now;

  static const queueCapacity = 64;

  final _subscribers = <AiInferenceSseSubscriber>[];
  Timer? _idleTimer;
  AiInferenceSessionStart? _activeSession;

  int get subscriberCount => _subscribers.length;

  bool get hasActiveSession => _activeSession != null;

  String? get activeSessionId => _activeSession?.sessionId;

  AiInferenceSseSubscriber acquire() {
    final connectedAt = _now();
    final sub = AiInferenceSseSubscriber._(this, connectedAt);
    _subscribers.add(sub);
    sub.offer(
      _encodeEvent(
        'idle',
        AiInferenceSseJson.idleData(
          timestampMs: 0,
          inferenceActive: _activeSession != null,
        ),
      ),
    );
    final session = _activeSession;
    if (session != null) {
      sub.offer(_encodeStart(sub, session, replay: true));
    }
    _ensureIdleTimer();
    return sub;
  }

  void release(AiInferenceSseSubscriber subscriber) {
    if (!_subscribers.remove(subscriber)) {
      return;
    }
    subscriber._closeInternal();
    if (_subscribers.isEmpty) {
      _idleTimer?.cancel();
      _idleTimer = null;
    }
  }

  void notifySessionStarted(AiInferenceSessionStart session) {
    _activeSession = session;
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      sub.offer(_encodeStart(sub, session, replay: false));
    }
  }

  void notifySessionStopped({
    required String sessionId,
    required String reason,
  }) {
    if (_activeSession?.sessionId == sessionId) {
      _activeSession = null;
    }
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      final ts = sub.connectionTimelineMs(_now());
      sub.offer(
        _encodeEvent(
          'stop',
          AiInferenceSseJson.stopData(
            sessionId: sessionId,
            timestampMs: ts,
            reason: reason,
          ),
        ),
      );
    }
  }

  void clearActiveSession() {
    _activeSession = null;
  }

  void publishRunning(AiInferenceRunningSample sample) {
    final sessionId = _activeSession?.sessionId;
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      final ts = sub.connectionTimelineMs(_now());
      sub.offer(
        _encodeEvent(
          'running',
          AiInferenceSseJson.runningData(
            timestampMs: ts,
            sessionId: sessionId,
            success: sample.success,
            code: sample.code,
            level: sample.level,
            status: sample.status,
            message: sample.message,
            imageWidth: sample.imageWidth,
            imageHeight: sample.imageHeight,
            source: sample.source,
            boxes: sample.boxes,
          ),
        ),
      );
    }
  }

  void publishError({required int code, required String message}) {
    final frame = _encodeEvent(
      'error',
      AiInferenceSseJson.errorData(code: code, message: message),
    );
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      sub.offer(frame);
      sub._closeInternal();
    }
    _subscribers.clear();
    _activeSession = null;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void resetForTest() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _activeSession = null;
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      sub._closeInternal();
    }
    _subscribers.clear();
  }

  /// Test hook: force periodic idle evaluation.
  void emitPeriodicIdleForTest() => _emitPeriodicIdle();

  void _ensureIdleTimer() {
    if (_idleTimer != null) {
      return;
    }
    _idleTimer = Timer.periodic(idleInterval, (_) => _emitPeriodicIdle());
  }

  void _emitPeriodicIdle() {
    if (_subscribers.isEmpty) {
      return;
    }
    final active = _activeSession != null;
    for (final sub in List<AiInferenceSseSubscriber>.from(_subscribers)) {
      final ts = sub.connectionTimelineMs(_now());
      sub.offer(
        _encodeEvent(
          'idle',
          AiInferenceSseJson.idleData(
            timestampMs: ts,
            inferenceActive: active,
          ),
        ),
      );
    }
  }

  List<int> _encodeStart(
    AiInferenceSseSubscriber sub,
    AiInferenceSessionStart session, {
    required bool replay,
  }) {
    final ts = replay ? 0 : sub.connectionTimelineMs(_now());
    return _encodeEvent(
      'start',
      AiInferenceSseJson.startData(
        sessionId: session.sessionId,
        timestampMs: ts,
        source: session.source,
        samplingIntervalMs: session.samplingIntervalMs,
        imageWidth: session.imageWidth,
        imageHeight: session.imageHeight,
      ),
    );
  }

  static String encodeEvent(String event, String jsonData) =>
      'event: $event\ndata: $jsonData\n\n';

  static List<int> _encodeEvent(String event, String jsonData) =>
      utf8.encode(encodeEvent(event, jsonData));
}

final class AiInferenceSseSubscriber {
  AiInferenceSseSubscriber._(this._hub, this.connectedAt);

  final AiInferenceSseHub _hub;
  final DateTime connectedAt;
  final _queue = StreamController<List<int>>.broadcast(sync: true);
  final _pending = <List<int>>[];
  bool _closed = false;

  bool get isClosed => _closed;

  int connectionTimelineMs(DateTime now) {
    final ms = now.difference(connectedAt).inMilliseconds;
    return ms < 0 ? 0 : ms;
  }

  Stream<List<int>> get frames async* {
    while (_pending.isNotEmpty) {
      yield _pending.removeAt(0);
    }
    yield* _queue.stream;
  }

  void offer(List<int> frame) {
    if (_closed) {
      return;
    }
    if (_queue.hasListener) {
      _queue.add(frame);
      return;
    }
    if (_pending.length >= AiInferenceSseHub.queueCapacity) {
      _pending.removeAt(0);
    }
    _pending.add(frame);
  }

  void _closeInternal() {
    _closed = true;
    if (!_queue.isClosed) {
      unawaited(_queue.close());
    }
  }

  void closeFromClient() {
    if (_closed) {
      return;
    }
    _hub.release(this);
  }
}
