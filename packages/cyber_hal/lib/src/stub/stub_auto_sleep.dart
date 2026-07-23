import 'dart:async';

import 'package:cyber_hal/output/display/auto_sleep.dart';
import 'package:cyber_hal/output/display/backlight.dart';

/// In-memory AutoSleep for host tests / sim.
final class StubAutoSleep implements AutoSleep {
  StubAutoSleep({
    AutoSleepPolicy initialPolicy = AutoSleepPolicy.never,
    this.doubleTapWindow = const Duration(milliseconds: 400),
  }) : _policy = initialPolicy;

  final Duration doubleTapWindow;

  AutoSleepPolicy _policy;
  bool _blanked = false;
  Backlight? _backlight;
  int? _savedPercent;
  DateTime? _lastBlankedTap;

  @override
  bool get isBlanked => _blanked;

  @override
  Future<AutoSleepPolicy> getPolicy() async => _policy;

  @override
  Future<void> setPolicy(AutoSleepPolicy policy) async {
    _policy = policy;
    if (policy == AutoSleepPolicy.never && _blanked) {
      await _restore();
    }
  }

  @override
  void arm({required Backlight backlight}) {
    _backlight = backlight;
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
  }

  /// Test helper: force blank as if idle elapsed.
  Future<void> forceBlankForTest() async {
    final bl = _backlight;
    if (bl == null || _blanked) {
      return;
    }
    _savedPercent = await bl.getBrightnessPercent();
    await bl.setAbsoluteBrightness(0);
    _blanked = true;
    _lastBlankedTap = null;
  }

  Future<void> _restore() async {
    final bl = _backlight;
    if (bl == null || !_blanked) {
      _blanked = false;
      return;
    }
    await bl.setBrightnessPercent(_savedPercent ?? 80);
    _blanked = false;
    _savedPercent = null;
    _lastBlankedTap = null;
  }

  @override
  Future<void> dispose() async {
    if (_blanked) {
      await _restore();
    }
    _backlight = null;
  }
}
