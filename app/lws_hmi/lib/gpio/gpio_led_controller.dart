import 'dart:async';

import 'package:cyber_hal/gpio.dart';
import 'package:cyber_hal/cyber_hal.dart' show BoardProfile;
import 'package:flutter/foundation.dart';
import 'package:lws_hmi/hal/hal_assets.dart';

/// Side-panel RGB indicators — product channel ids (bindings in gpio.json).
///
/// Hardware maps live in [HmiHalAssets.gpio] / [HmiHalAssets.gpioSim], not here.
enum LedColor {
  red(channelId: 'red', lineId: 'led_red'),
  yellow(channelId: 'yellow', lineId: 'led_yellow'),
  green(channelId: 'green', lineId: 'led_green');

  const LedColor({required this.channelId, required this.lineId});

  /// Status LED bank channel id in product gpio config.
  final String channelId;

  /// Legacy line / alias id (v1 configs and level listener aliases).
  final String lineId;

  static const bankId = 'chassis_rgb';
}

/// Modes aligned with lws-ui `IndicatorMode` (Steady / Blink / Off).
enum IndicatorMode {
  off,
  blink,
  steadyOn,
}

/// Thin App façade over [GpioHal] Status LED bank for Demo / emulator overlay.
///
/// [isOn] tracks HAL levels via [GpioHal.addLevelListener] (including blink).
class GpioLedController extends ChangeNotifier {
  GpioLedController({
    GpioHal? hal,
    BoardProfile? profile,
    Future<GpioHal>? halFuture,
  })  : _hal = hal,
        _profile = profile,
        _loading = halFuture;

  GpioHal? _hal;
  StatusLedBank? _bank;
  final BoardProfile? _profile;
  Future<GpioHal>? _loading;
  final Map<LedColor, IndicatorMode?> _modes = {
    for (final c in LedColor.values) c: null,
  };
  final Map<LedColor, bool> _on = {
    for (final c in LedColor.values) c: false,
  };
  final Map<String, LedColor> _idToColor = {
    for (final c in LedColor.values) ...{
      c.channelId: c,
      c.lineId: c,
      '${LedColor.bankId}/${c.channelId}': c,
    },
  };
  bool _watching = false;
  late final GpioLevelListener _levelListener = _onHalLevel;

  IndicatorMode modeOf(LedColor color) => _modes[color] ?? IndicatorMode.off;

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

  Future<StatusLedBank> _ensureBank() async {
    final existing = _bank;
    if (existing != null) return existing;
    final hal = await _ensureHal();
    final bank = hal.openStatusLed(LedColor.bankId);
    _bank = bank;
    return bank;
  }

  /// Subscribe to HAL level callbacks and seed [isOn].
  Future<void> ensureWatching() async {
    if (_watching) {
      return;
    }
    _watching = true;
    try {
      final hal = await _ensureHal();
      final bank = await _ensureBank();
      hal.addLevelListener(_levelListener);
      for (final color in LedColor.values) {
        try {
          _on[color] = await bank.isOn(color.channelId);
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
    final color = _idToColor[lineId];
    if (color == null) {
      return;
    }
    if (_on[color] == logicalHigh) {
      return;
    }
    _on[color] = logicalHigh;
    notifyListeners();
  }

  /// Force all RGB channels Off (cancels blink). Call once at boot before policy.
  Future<void> resetAllOff() async {
    try {
      final bank = await _ensureBank();
      if (!_watching) {
        await ensureWatching();
      }
      for (final color in LedColor.values) {
        await bank.setMode(color.channelId, LedMode.off, force: true);
        _modes[color] = IndicatorMode.off;
        _on[color] = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('GPIO LED: resetAllOff failed: $e');
    }
  }

  Future<void> setMode(LedColor color, IndicatorMode mode) async {
    if (_modes[color] == mode) {
      return;
    }
    try {
      final bank = await _ensureBank();
      if (!_watching) {
        await ensureWatching();
      }
      await bank.setMode(color.channelId, _toLedMode(mode));
      _modes[color] = mode;
      notifyListeners();
    } catch (e) {
      debugPrint('GPIO LED ${color.name}: setMode failed: $e');
    }
  }

  static LedMode _toLedMode(IndicatorMode mode) {
    switch (mode) {
      case IndicatorMode.off:
        return LedMode.off;
      case IndicatorMode.steadyOn:
        return LedMode.steady;
      case IndicatorMode.blink:
        return LedMode.blink;
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
    _bank = null;
    for (final c in LedColor.values) {
      _modes[c] = null;
      _on[c] = false;
    }
    super.dispose();
  }
}
