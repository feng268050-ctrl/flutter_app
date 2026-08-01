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
  bool _use24HourFormat = true;
  bool _started = false;

  DateTime get now => _now;

  /// Display preference from HAL (`use_24h`, default on).
  bool get use24HourFormat => _use24HourFormat;

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

  Future<void> setUse24HourFormat(bool enabled) async {
    await _dt.setUse24HourFormat(enabled);
    if (_use24HourFormat == enabled) {
      return;
    }
    _use24HourFormat = enabled;
    notifyListeners();
  }

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
