import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:flutter/foundation.dart';

/// App-wide wall clock for OS Settings status bar.
final class OsWallClock extends ChangeNotifier {
  OsWallClock(this._dt);

  final DateTimeController _dt;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _use24HourFormat = true;
  bool _started = false;

  DateTime get now => _now;
  bool get use24HourFormat => _use24HourFormat;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick(notifyAlways: false));
    });
  }

  Future<void> refresh() => _tick(notifyAlways: true);

  Future<void> _tick({required bool notifyAlways}) async {
    try {
      final next = await _dt.now();
      final use24 = await _dt.getUse24HourFormat();
      final timeChanged = next.year != _now.year ||
          next.month != _now.month ||
          next.day != _now.day ||
          next.hour != _now.hour ||
          next.minute != _now.minute;
      final formatChanged = use24 != _use24HourFormat;
      _now = next;
      _use24HourFormat = use24;
      if (notifyAlways || timeChanged || formatChanged) {
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
