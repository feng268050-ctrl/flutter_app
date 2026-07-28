import 'dart:async';

import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/cyber_hal.dart' show BoardProfile;
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/hal/hal_assets.dart';

/// Side-panel RGB indicators — product names mapped to HAL line ids.
///
/// Pin numbers live in [HmiHalAssets.gpio] / [HmiHalAssets.gpioSim], not here.
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

/// Thin App façade over [GpioHal] for Demo LED rows / emulator overlay.
///
/// [isOn] tracks HAL line levels: one [GpioLine.get] snapshot in
/// [ensureWatching], then [GpioHal.addLevelListener] on every [GpioLine.set]
/// (including HAL blink ticks). No UI/HAL duplicate blink timer in the App.
class GpioLedController extends ChangeNotifier {
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
  final Map<LedColor, bool> _on = {
    for (final c in LedColor.values) c: false,
  };
  final Map<String, LedColor> _lineToColor = {
    for (final c in LedColor.values) c.lineId: c,
  };
  bool _watching = false;
  late final GpioLevelListener _levelListener = _onHalLevel;

  IndicatorMode modeOf(LedColor color) => _modes[color]!;

  /// Logical line level from HAL (active-high after active_low mapping).
  bool isOn(LedColor color) => _on[color]!;

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
            : GpioHal.fromAsset(asset: HmiHalAssets.gpio))
        .then((h) {
      _hal = h;
      return h;
    });
  }

  /// Subscribe to HAL level callbacks and seed [isOn] from [GpioLine.get].
  ///
  /// Idempotent — call from the LED overlay when it mounts.
  Future<void> ensureWatching() async {
    if (_watching) {
      return;
    }
    _watching = true;
    try {
      final hal = await _ensureHal();
      for (final color in LedColor.values) {
        // Open lines so blink set() paths share the same handles.
        hal.openLine(color.lineId);
      }
      hal.addLevelListener(_levelListener);
      for (final color in LedColor.values) {
        try {
          _on[color] = await hal.openLine(color.lineId).get();
        } catch (e) {
          debugPrint('GPIO LED ${color.name}: initial get failed: $e');
          _on[color] = false;
        }
      }
      notifyListeners();
    } catch (e) {
      _watching = false;
      debugPrint('GPIO LED: ensureWatching failed: $e');
    }
  }

  void _onHalLevel(String lineId, bool logicalHigh) {
    final color = _lineToColor[lineId];
    if (color == null) {
      return;
    }
    if (_on[color] == logicalHigh) {
      return;
    }
    _on[color] = logicalHigh;
    notifyListeners();
  }

  Future<void> setMode(LedColor color, IndicatorMode mode) async {
    _modes[color] = mode;
    notifyListeners();
    try {
      final hal = await _ensureHal();
      if (!_watching) {
        // Settings can change LEDs before overlay mounts — still get callbacks.
        await ensureWatching();
      }
      final line = hal.openLine(color.lineId);
      await line.setMode(_toHalMode(mode));
      // Level updates arrive via [GpioLevelListener] from each [GpioLine.set].
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

  @override
  void dispose() {
    final hal = _hal;
    if (hal != null) {
      if (_watching) {
        hal.removeLevelListener(_levelListener);
      }
      unawaited(hal.dispose());
    }
    _watching = false;
    for (final c in LedColor.values) {
      _modes[c] = IndicatorMode.off;
      _on[c] = false;
    }
    super.dispose();
  }
}
