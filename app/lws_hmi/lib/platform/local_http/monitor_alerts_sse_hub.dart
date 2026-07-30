import 'dart:async';
import 'dart:convert';

/// Fan-out SSE for `GET /v1/monitor/alerts`.
final class MonitorAlertsSseHub {
  MonitorAlertsSseHub({
    this.listSupplier,
    this.heartbeatInterval = const Duration(seconds: 15),
  });

  /// Current WarnTable-shaped rows for immediate `list` (newest-first, ≤10).
  Future<List<Object?>> Function()? listSupplier;

  final Duration heartbeatInterval;

  static const queueCapacity = 64;
  static const listLimit = 10;

  final _subscribers = <MonitorAlertsSseSubscriber>[];
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatAt;

  int get subscriberCount => _subscribers.length;

  Future<MonitorAlertsSseSubscriber> acquire() async {
    final sub = MonitorAlertsSseSubscriber._(this);
    _subscribers.add(sub);
    _ensureHeartbeat();
    final rows = listSupplier == null
        ? const <Object?>[]
        : await listSupplier!();
    sub.offer(_encodeEvent('list', jsonEncode(rows)));
    return sub;
  }

  void publishNew(Map<String, Object?> warnTable) {
    if (warnTable['id'] == null) {
      return;
    }
    final frame = _encodeEvent('new', jsonEncode(warnTable));
    _fanOut(frame);
  }

  void publishClear() {
    _fanOut(_encodeEvent('clear', '{}'));
  }

  void release(MonitorAlertsSseSubscriber subscriber) {
    if (!_subscribers.remove(subscriber)) {
      return;
    }
    subscriber._closeInternal();
    if (_subscribers.isEmpty) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _lastHeartbeatAt = null;
    }
  }

  void resetForTest() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _lastHeartbeatAt = null;
    for (final sub in List<MonitorAlertsSseSubscriber>.from(_subscribers)) {
      sub._closeInternal();
    }
    _subscribers.clear();
  }

  void _fanOut(List<int> frame) {
    if (_subscribers.isEmpty) {
      return;
    }
    for (final sub in List<MonitorAlertsSseSubscriber>.from(_subscribers)) {
      sub.offer(frame);
    }
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
    _fanOut(_encodeEvent('heartbeat', '{"ok":true}'));
  }

  void heartbeatTickForTest([DateTime? now]) {
    if (_subscribers.isEmpty) {
      return;
    }
    final at = now ?? DateTime.now();
    final due = _lastHeartbeatAt == null ||
        at.difference(_lastHeartbeatAt!) >= heartbeatInterval;
    if (!due) {
      return;
    }
    _lastHeartbeatAt = at;
    _fanOut(_encodeEvent('heartbeat', '{"ok":true}'));
  }

  static String encodeEvent(String event, String jsonData) =>
      'event: $event\ndata: $jsonData\n\n';

  static List<int> _encodeEvent(String event, String jsonData) =>
      utf8.encode(encodeEvent(event, jsonData));
}

final class MonitorAlertsSseSubscriber {
  MonitorAlertsSseSubscriber._(this._hub);

  final MonitorAlertsSseHub _hub;
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
    if (_pending.length >= MonitorAlertsSseHub.queueCapacity) {
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
