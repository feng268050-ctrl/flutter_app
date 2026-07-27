import 'dart:async';

import 'package:cyber_hal/datetime.dart';
import 'package:flutter/foundation.dart';

/// App-wide wall clock driven by [DateTimeController.now] (OS civil time).
///
/// Status / Home clocks should read [now] and listen to this listenable so they
/// track Settings changes within ~1s and stay correct when Dart ICU TZ is UTC.
final class OsWallClock extends ChangeNotifier {
  OsWallClock(this._dt);

  final DateTimeController _dt;
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _started = false;

  DateTime get now => _now;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick(notifyAlways: false));
    });
  }

  /// Force re-read (call after [DateTimeController.setWallClock] / setTimezone).
  Future<void> refresh() => _tick(notifyAlways: true);

  Future<void> _tick({required bool notifyAlways}) async {
    try {
      final next = await _dt.now();
      final changed = next.year != _now.year ||
          next.month != _now.month ||
          next.day != _now.day ||
          next.hour != _now.hour ||
          next.minute != _now.minute;
      _now = next;
      if (notifyAlways || changed) {
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
