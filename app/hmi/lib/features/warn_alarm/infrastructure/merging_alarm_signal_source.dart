import 'dart:async';

import 'package:cyber_alarm/cyber_alarm.dart';

/// Forwards events from multiple [AlarmSignalSource]s into one stream.
final class MergingAlarmSignalSource implements AlarmSignalSource {
  MergingAlarmSignalSource(List<AlarmSignalSource> sources) {
    for (final source in sources) {
      _subs.add(source.events.listen(_onEvent));
    }
  }

  final _controller = StreamController<AlarmSignalEvent>.broadcast(sync: true);
  final List<StreamSubscription<AlarmSignalEvent>> _subs = [];

  @override
  Stream<AlarmSignalEvent> get events => _controller.stream;

  void _onEvent(AlarmSignalEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await _controller.close();
  }
}
