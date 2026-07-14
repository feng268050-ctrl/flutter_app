import 'dart:async';
import 'dart:io';

import 'package:lws_hmi/gpio/gpio_led_config.dart';

/// Low-level GPIO line writer: prefer Innohi own-gpio, else classic sysfs.
class GpioLineBackend {
  GpioLineBackend();

  String? _activeScheme;
  final Map<int, String> _valuePaths = <int, String>{};

  String? get activeScheme => _activeScheme;

  Future<bool> ensureOutput(int pin) async {
    if (_valuePaths.containsKey(pin)) {
      return true;
    }

    final candidates = <String>[
      '/sys/class/own-gpio/gpio$pin/value',
      '/sys/class/own_gpio/gpio$pin/value',
      '/sys/devices/platform/own-gpio/gpio$pin/value',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        _valuePaths[pin] = path;
        _activeScheme ??= 'own-gpio';
        await _trySetDirectionSibling(path, 'out');
        return true;
      }
    }

    // Classic sysfs fallback (pin number remains the product abstract index).
    final export = File('/sys/class/gpio/export');
    final valuePath = '/sys/class/gpio/gpio$pin/value';
    final valueFile = File(valuePath);
    if (!await valueFile.exists()) {
      try {
        await export.writeAsString('$pin');
      } catch (_) {
        // May already be exported.
      }
    }
    if (await valueFile.exists()) {
      final direction = File('/sys/class/gpio/gpio$pin/direction');
      try {
        await direction.writeAsString('out');
      } catch (_) {}
      _valuePaths[pin] = valuePath;
      _activeScheme ??= 'sysfs';
      return true;
    }
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

  Future<bool> writeLevel(int pin, bool high) async {
    if (!await ensureOutput(pin)) {
      return false;
    }
    final path = _valuePaths[pin]!;
    try {
      await File(path).writeAsString(high ? '1' : '0');
      return true;
    } catch (_) {
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
        await _backend.writeLevel(color.pin, false);
      case IndicatorMode.steadyOn:
        await _backend.writeLevel(color.pin, true);
      case IndicatorMode.blink:
        _blinkPhaseHigh[color] = true;
        await _backend.writeLevel(color.pin, true);
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
    await _backend.writeLevel(color.pin, next);
  }

  void _cancelBlink(LedColor color) {
    _blinkTimers[color]?.cancel();
    _blinkTimers[color] = null;
  }

  Future<void> dispose() async {
    for (final color in LedColor.values) {
      _cancelBlink(color);
      await _backend.writeLevel(color.pin, false);
      _modes[color] = IndicatorMode.off;
    }
  }
}
