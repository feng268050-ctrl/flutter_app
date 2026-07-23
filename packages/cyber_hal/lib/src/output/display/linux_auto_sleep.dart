import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cyber_hal/output/display/auto_sleep.dart';
import 'package:cyber_hal/output/display/backlight.dart';
import 'package:cyber_hal/src/linux/key_value_conf.dart';
import 'package:cyber_hal/src/output/output_prefs.dart';

/// Linux AutoSleep: persist policy; blank with absolute sysfs 0; double-tap wake.
final class LinuxAutoSleep implements AutoSleep {
  LinuxAutoSleep({
    this.preferencePath = OutputPrefs.displayConf,
    AutoSleepPolicy initialPolicy = AutoSleepPolicy.never,
    this.tickInterval = const Duration(seconds: 15),
    this.doubleTapWindow = const Duration(milliseconds: 400),
  }) : _policy = initialPolicy;

  final String preferencePath;
  final Duration tickInterval;
  final Duration doubleTapWindow;

  AutoSleepPolicy _policy;
  bool _warmed = false;
  Backlight? _backlight;
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  DateTime? _lastBlankedTap;
  bool _blanked = false;
  int? _savedPercent;
  bool _disposed = false;

  @override
  bool get isBlanked => _blanked;

  @override
  Future<AutoSleepPolicy> getPolicy() async {
    await _ensureWarmed();
    return _policy;
  }

  @override
  Future<void> setPolicy(AutoSleepPolicy policy) async {
    _policy = policy;
    _warmed = true;
    await upsertKeyValueConfFile(preferencePath, {
      OutputPrefs.keyAutoSleep: policy.wireName,
    });
    if (_policy == AutoSleepPolicy.never && _blanked) {
      await _restore();
    }
    _reschedule();
  }

  @override
  void arm({required Backlight backlight}) {
    if (_disposed) {
      return;
    }
    _backlight = backlight;
    unawaited(_ensureWarmed().then((_) {
      if (!_disposed) {
        _reschedule();
      }
    }));
  }

  @override
  void noteActivity() {
    if (_blanked) {
      final now = DateTime.now();
      final prev = _lastBlankedTap;
      _lastBlankedTap = now;
      if (prev != null && now.difference(prev) <= doubleTapWindow) {
        _lastBlankedTap = null;
        unawaited(_restore());
      }
      return;
    }
    _lastActivity = DateTime.now();
    _reschedule();
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    if (_disposed || _backlight == null) {
      return;
    }
    final idle = _policy.idleDuration;
    if (idle == null) {
      return;
    }
    _timer = Timer.periodic(tickInterval, (_) {
      unawaited(_onTick());
    });
  }

  Future<void> _onTick() async {
    if (_disposed || _blanked) {
      return;
    }
    final idle = _policy.idleDuration;
    if (idle == null) {
      return;
    }
    final elapsed = DateTime.now().difference(_lastActivity);
    if (elapsed >= idle) {
      await _blank();
    }
  }

  Future<void> _blank() async {
    final bl = _backlight;
    if (bl == null || _blanked) {
      return;
    }
    try {
      _savedPercent = await bl.getBrightnessPercent();
      await bl.setAbsoluteBrightness(0);
      _blanked = true;
      _lastBlankedTap = null;
      debugPrint('auto-sleep: blanked absolute 0 (saved=$_savedPercent)');
    } catch (e) {
      debugPrint('auto-sleep: blank failed: $e');
    }
  }

  Future<void> _restore() async {
    final bl = _backlight;
    if (bl == null || !_blanked) {
      _blanked = false;
      return;
    }
    final pct = _savedPercent ?? 80;
    try {
      // Restore logical brightness without rewriting preference semantics:
      // setBrightnessPercent persists — preferred so panel matches operator pref.
      await bl.setBrightnessPercent(pct);
      debugPrint('auto-sleep: restored $pct%');
    } catch (e) {
      debugPrint('auto-sleep: restore failed: $e');
    } finally {
      _blanked = false;
      _savedPercent = null;
      _lastBlankedTap = null;
      _lastActivity = DateTime.now();
      _reschedule();
    }
  }

  Future<void> _ensureWarmed() async {
    if (_warmed) {
      return;
    }
    try {
      final map = await readKeyValueConfFile(preferencePath);
      final raw = map[OutputPrefs.keyAutoSleep];
      if (raw != null) {
        _policy = AutoSleepPolicy.parse(raw);
      }
    } catch (e) {
      debugPrint('auto-sleep: read failed: $e');
    }
    _warmed = true;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_blanked) {
      await _restore();
    }
    _backlight = null;
  }
}
