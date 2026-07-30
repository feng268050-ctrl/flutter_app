import 'dart:async';
import 'dart:convert';

import 'package:lws_hmi/platform/local_http/monitor_stat_snapshot.dart';

/// Fan-out SSE for `GET /v1/monitor/stat` (event-driven; no 100ms sampler).
///
/// lws-ui field/event names; push model follows HAL `watchAttributes` via
/// [publishStat] rather than Android's MemoryCache poll timer.
final class MonitorStatSseHub {
  MonitorStatSseHub({
    this.snapshotSupplier,
    this.heartbeatInterval = const Duration(seconds: 15),
  });

  /// Sync snapshot for immediate emit on acquire (LiveCache).
  MonitorStatSnapshot Function()? snapshotSupplier;

  final Duration heartbeatInterval;

  static const queueCapacity = 64;

  final _subscribers = <MonitorStatSseSubscriber>[];
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatAt;
  MonitorStatSnapshot? _lastEmitted;

  int get subscriberCount => _subscribers.length;

  MonitorStatSseSubscriber acquire() {
    final sub = MonitorStatSseSubscriber._(this);
    _subscribers.add(sub);
    _ensureHeartbeat();
    final snap = (snapshotSupplier?.call() ?? MonitorStatSnapshot.empty).copy();
    _lastEmitted = snap;
    sub.offer(_encodeEvent('stat', jsonEncode(snap.toJson())));
    return sub;
  }

  /// Publish a fresh snapshot when LiveCache / process store changes.
  void publishStat(MonitorStatSnapshot snapshot) {
    if (_subscribers.isEmpty) {
      _lastEmitted = snapshot.copy();
      return;
    }
    if (!snapshot.changedSince(_lastEmitted)) {
      return;
    }
    _lastEmitted = snapshot.copy();
    final frame = _encodeEvent('stat', jsonEncode(_lastEmitted!.toJson()));
    for (final sub in List<MonitorStatSseSubscriber>.from(_subscribers)) {
      sub.offer(frame);
    }
  }

  void release(MonitorStatSseSubscriber subscriber) {
    if (!_subscribers.remove(subscriber)) {
      return;
    }
    subscriber._closeInternal();
    if (_subscribers.isEmpty) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _lastHeartbeatAt = null;
      _lastEmitted = null;
    }
  }

  void resetForTest() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastHeartbeatAt = null;
    _lastEmitted = null;
    for (final sub in List<MonitorStatSseSubscriber>.from(_subscribers)) {
      sub._closeInternal();
    }
    _subscribers.clear();
  }

  void _ensureHeartbeat() {
    if (_heartbeatTimer != null) {
      return;
    }
    _heartbeatTick();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => _heartbeatTick());
  }

  void _heartbeatTick() {
    if (_subscribers.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final due = _lastHeartbeatAt == null ||
        now.difference(_lastHeartbeatAt!) >= heartbeatInterval;
    if (!due) {
      return;
    }
    _lastHeartbeatAt = now;
    final frame = _encodeEvent('heartbeat', '{"ok":true}');
    for (final sub in List<MonitorStatSseSubscriber>.from(_subscribers)) {
      sub.offer(frame);
    }
  }

  /// Test hook: force a heartbeat evaluation at [now].
  void heartbeatTickForTest([DateTime? now]) {
    final previous = heartbeatInterval;
    // Direct emit for tests without waiting on timer.
    if (_subscribers.isEmpty) {
      return;
    }
    final at = now ?? DateTime.now();
    final due = _lastHeartbeatAt == null ||
        at.difference(_lastHeartbeatAt!) >= previous;
    if (!due) {
      return;
    }
    _lastHeartbeatAt = at;
    final frame = _encodeEvent('heartbeat', '{"ok":true}');
    for (final sub in List<MonitorStatSseSubscriber>.from(_subscribers)) {
      sub.offer(frame);
    }
  }

  static String encodeEvent(String event, String jsonData) =>
      'event: $event\ndata: $jsonData\n\n';

  static List<int> _encodeEvent(String event, String jsonData) =>
      utf8.encode(encodeEvent(event, jsonData));
}

final class MonitorStatSseSubscriber {
  MonitorStatSseSubscriber._(this._hub);

  final MonitorStatSseHub _hub;
  final _queue = StreamController<List<int>>.broadcast(sync: true);
  final _pending = <List<int>>[];
  bool _closed = false;

  bool get isClosed => _closed;

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
    if (_pending.length >= MonitorStatSseHub.queueCapacity) {
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
