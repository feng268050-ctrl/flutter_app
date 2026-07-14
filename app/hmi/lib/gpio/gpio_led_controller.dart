import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/gpio/gpio_led_config.dart';
import 'package:lws_hmi/platform/lws_trace.dart';

/// Low-level GPIO writer for ynh960 side-panel LEDs.
///
/// Resolution order per [LedColor]:
/// 1. Innohi `gpio_innohi` sysfs using DTS labels GPIO_5 / GPIO_4 / GPIO_7
/// 2. Classic `/sys/class/gpio` using Linux SoC numbers (105 / 106 / 149)
class GpioLineBackend {
  GpioLineBackend();

  String? _activeScheme;
  final Map<int, String> _valuePaths = <int, String>{};

  String? get activeScheme => _activeScheme;

  Future<bool> ensureColor(LedColor color) async {
    final key = color.ynhApiPin;
    if (_valuePaths.containsKey(key)) {
      return true;
    }

    // Innohi gpio_innohi (compatible gpio-innohi): class uses DTS labels.
    final ownCandidates = <String>[
      '/sys/class/gpio_innohi/GPIO_${color.ynhApiPin}/value',
      '/sys/class/gpio_innohi/gpio${color.ynhApiPin}/value',
    ];
    for (final path in ownCandidates) {
      if (await File(path).exists()) {
        _valuePaths[key] = path;
        _activeScheme ??= 'gpio_innohi(GPIO_${color.ynhApiPin})';
        await _trySetDirectionSibling(path, 'out');
        lwsTrace('GPIO ${color.name}: using $path');
        return true;
      }
    }

    // Classic sysfs with Linux global GPIO number from DTS pad mapping.
    final linux = color.linuxGpio;
    final export = File('/sys/class/gpio/export');
    final valuePath = '/sys/class/gpio/gpio$linux/value';
    final valueFile = File(valuePath);
    if (!await valueFile.exists()) {
      try {
        await export.writeAsString('$linux');
        // export is async in the kernel; give the node a moment.
        await Future<void>.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        debugPrint('GPIO ${color.name}: export $linux failed: $e');
      }
    }
    if (await valueFile.exists()) {
      final direction = File('/sys/class/gpio/gpio$linux/direction');
      try {
        await direction.writeAsString('out');
      } catch (e) {
        debugPrint('GPIO ${color.name}: direction out failed: $e');
      }
      _valuePaths[key] = valuePath;
      _activeScheme ??= 'sysfs(linux=$linux)';
      lwsTrace('GPIO ${color.name}: using $valuePath '
          '(ynhApi=${color.ynhApiPin} → linux=$linux)');
      return true;
    }

    debugPrint(
      'GPIO ${color.name}: no backend '
      '(tried gpio_innohi GPIO_${color.ynhApiPin}, sysfs linux=$linux)',
    );
    return false;
  }

  Future<void> _trySetDirectionSibling(String valuePath, String direction) async {
    final dirPath = valuePath.replaceFirst(RegExp(r'/value$'), '/direction');
    final file = File(dirPath);
    if (await file.exists()) {
      try {
        await file.writeAsString(direction);
      } catch (_) {}
    }
  }

  Future<bool> writeColor(LedColor color, bool high) async {
    if (!await ensureColor(color)) {
      return false;
    }
    final path = _valuePaths[color.ynhApiPin]!;
    try {
      await File(path).writeAsString(high ? '1' : '0');
      return true;
    } catch (e) {
      debugPrint('GPIO ${color.name}: write $path failed: $e');
      return false;
    }
  }
}

/// Per-color LED controller with Steady / Blink / Off (colors independent).
class GpioLedController {
  GpioLedController({GpioLineBackend? backend})
      : _backend = backend ?? GpioLineBackend();

  final GpioLineBackend _backend;
  final Map<LedColor, IndicatorMode> _modes = {
    for (final c in LedColor.values) c: IndicatorMode.off,
  };
  final Map<LedColor, Timer?> _blinkTimers = {
    for (final c in LedColor.values) c: null,
  };
  final Map<LedColor, bool> _blinkPhaseHigh = {
    for (final c in LedColor.values) c: false,
  };

  IndicatorMode modeOf(LedColor color) => _modes[color]!;

  String? get backendScheme => _backend.activeScheme;

  Future<void> setMode(LedColor color, IndicatorMode mode) async {
    _cancelBlink(color);
    _modes[color] = mode;
    switch (mode) {
      case IndicatorMode.off:
        await _backend.writeColor(color, false);
      case IndicatorMode.steadyOn:
        await _backend.writeColor(color, true);
      case IndicatorMode.blink:
        _blinkPhaseHigh[color] = true;
        await _backend.writeColor(color, true);
        _blinkTimers[color] = Timer.periodic(
          const Duration(milliseconds: GpioLedConfig.flashOnMs),
          (_) => _onBlinkTick(color),
        );
    }
  }

  Future<void> _onBlinkTick(LedColor color) async {
    if (_modes[color] != IndicatorMode.blink) {
      return;
    }
    final next = !(_blinkPhaseHigh[color] ?? false);
    _blinkPhaseHigh[color] = next;
    await _backend.writeColor(color, next);
  }

  void _cancelBlink(LedColor color) {
    _blinkTimers[color]?.cancel();
    _blinkTimers[color] = null;
  }

  Future<void> dispose() async {
    for (final color in LedColor.values) {
      _cancelBlink(color);
      await _backend.writeColor(color, false);
      _modes[color] = IndicatorMode.off;
    }
  }
}
