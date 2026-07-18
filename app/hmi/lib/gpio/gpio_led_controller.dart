import 'dart:async';

import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/cyber_hal.dart' show BoardProfile;
import 'package:flutter/foundation.dart';

/// Side-panel RGB indicators — product names mapped to HAL line ids.
///
/// Pin numbers live in `boards/ynh960/gpio.json`, not here.
enum LedColor {
  red(lineId: 'led_red'),
  yellow(lineId: 'led_yellow'),
  green(lineId: 'led_green');

  const LedColor({required this.lineId});

  final String lineId;
}

/// Modes aligned with lws-ui `IndicatorMode` (Steady / Blink / Off).
enum IndicatorMode {
  off,
  blink,
  steadyOn,
}

/// Thin App façade over [GpioHal] for Demo LED rows.
class GpioLedController {
  GpioLedController({
    GpioHal? hal,
    BoardProfile? profile,
    Future<GpioHal>? halFuture,
  })  : _hal = hal,
        _profile = profile,
        _loading = halFuture;

  GpioHal? _hal;
  final BoardProfile? _profile;
  Future<GpioHal>? _loading;
  final Map<LedColor, IndicatorMode> _modes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };

  IndicatorMode modeOf(LedColor color) => _modes[color]!;

  /// Loaded board gpio config (after first ensure).
  Future<GpioConfig> get config async => (await _ensureHal()).config;

  Future<GpioHal> _ensureHal() {
    if (_hal != null) {
      return Future<GpioHal>.value(_hal);
    }
    if (_loading != null) {
      return _loading!.then((h) {
        _hal = h;
        return h;
      });
    }
    final profile = _profile;
    return _loading ??= (profile != null
            ? GpioHal.fromProfile(profile)
            : GpioHal.fromAsset())
        .then((h) {
      _hal = h;
      return h;
    });
  }

  Future<void> setMode(LedColor color, IndicatorMode mode) async {
    _modes[color] = mode;
    try {
      final hal = await _ensureHal();
      final line = hal.openLine(color.lineId);
      await line.setMode(_toHalMode(mode));
    } catch (e) {
      debugPrint('GPIO LED ${color.name}: setMode failed: $e');
    }
  }

  static GpioLineMode _toHalMode(IndicatorMode mode) {
    switch (mode) {
      case IndicatorMode.off:
        return GpioLineMode.off;
      case IndicatorMode.steadyOn:
        return GpioLineMode.steady;
      case IndicatorMode.blink:
        return GpioLineMode.blink;
    }
  }

  Future<void> dispose() async {
    final hal = _hal;
    if (hal != null) {
      await hal.dispose();
    }
    for (final c in LedColor.values) {
      _modes[c] = IndicatorMode.off;
    }
  }
}
