import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/gpio_config.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

/// Fired after a successful [GpioLine.set] with the **logical** level
/// (active-low already applied for the physical write).
typedef GpioLevelListener = void Function(String lineId, bool logicalHigh);

/// Config-driven GPIO HAL (sysfs / gpio_innohi).
abstract class GpioHal {
  GpioConfig get config;

  /// Open a named line by config id.
  GpioLine openLine(String id);

  /// Observe logical level changes from [GpioLine.set] (including blink ticks).
  void addLevelListener(GpioLevelListener listener);

  void removeLevelListener(GpioLevelListener listener);

  /// Release blink timers / cached paths.
  Future<void> dispose();

  factory GpioHal.fromConfig(GpioConfig config) = _LinuxGpioHal;

  /// Load JSON from a filesystem path (async — no `readAsStringSync`).
  static Future<GpioHal> fromConfigFile(String path) async {
    final source = await File(path).readAsString();
    return GpioHal.fromConfig(GpioConfig.fromJsonString(source));
  }

  /// Load JSON from a Flutter asset (product App typically owns `gpio.json`).
  static Future<GpioHal> fromAsset({
    required String asset,
    AssetBundle? bundle,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(asset);
    return GpioHal.fromConfig(GpioConfig.fromJsonString(source));
  }

  /// Prefer [BoardProfile.resolvedGpioAsset] when set (D22).
  static Future<GpioHal> fromProfile(
    BoardProfile profile, {
    AssetBundle? bundle,
  }) {
    final asset = profile.resolvedGpioAsset;
    if (asset == null || asset.isEmpty) {
      throw const HalIoException(
        'board profile missing configs.gpio asset path',
      );
    }
    return fromAsset(asset: asset, bundle: bundle);
  }
}

/// Named GPIO line handle.
abstract class GpioLine {
  String get id;

  Future<void> set(bool high);

  Future<bool> get();

  Future<void> setMode(GpioLineMode mode, {bool force = false});

  GpioLineMode get mode;
}

enum GpioLineMode { off, steady, blink }

final class _LinuxGpioHal implements GpioHal {
  _LinuxGpioHal(this.config);

  @override
  final GpioConfig config;

  final Map<String, _LinuxGpioLine> _open = {};
  final List<GpioLevelListener> _levelListeners = [];

  @override
  GpioLine openLine(String id) {
    final existing = _open[id];
    if (existing != null) {
      return existing;
    }
    final lineCfg = config.lineById(id);
    if (lineCfg == null) {
      throw HalNotFoundException('gpio line not found: $id');
    }
    final line = _LinuxGpioLine(
      lineCfg,
      defaults: config.defaults,
      capabilities: config.capabilities,
      onLogicalSet: _emitLevel,
    );
    _open[id] = line;
    return line;
  }

  @override
  void addLevelListener(GpioLevelListener listener) {
    if (!_levelListeners.contains(listener)) {
      _levelListeners.add(listener);
    }
  }

  @override
  void removeLevelListener(GpioLevelListener listener) {
    _levelListeners.remove(listener);
  }

  void _emitLevel(String lineId, bool logicalHigh) {
    // Copy in case a listener unregisters during notify.
    for (final listener in List<GpioLevelListener>.of(_levelListeners)) {
      listener(lineId, logicalHigh);
    }
  }

  @override
  Future<void> dispose() async {
    _levelListeners.clear();
    for (final line in _open.values) {
      await line.dispose();
    }
    _open.clear();
  }
}

final class _LinuxGpioLine implements GpioLine {
  _LinuxGpioLine(
    this._cfg, {
    required GpioDefaults defaults,
    required GpioCapabilities capabilities,
    required void Function(String lineId, bool logicalHigh) onLogicalSet,
  })  : _defaults = defaults,
        _capabilities = capabilities,
        _onLogicalSet = onLogicalSet;

  final GpioLineConfig _cfg;
  final GpioDefaults _defaults;
  final GpioCapabilities _capabilities;
  final void Function(String lineId, bool logicalHigh) _onLogicalSet;

  String? _valuePath;
  String? _activeScheme;
  GpioLineMode? _mode;
  Timer? _blinkTimer;
  bool _blinkPhaseHigh = false;

  @override
  String get id => _cfg.id;

  @override
  GpioLineMode get mode => _mode ?? GpioLineMode.off;

  String? get activeScheme => _activeScheme;

  Future<bool> _ensureBackend() async {
    if (_valuePath != null) {
      return true;
    }

    final candidates = <String>[
      if (_cfg.path != null && _cfg.path!.isNotEmpty) _cfg.path!,
      if (_cfg.label != null && _cfg.label!.isNotEmpty) ...[
        '/sys/class/gpio_innohi/${_cfg.label}/value',
        '/sys/class/gpio_innohi/${_cfg.label!.toLowerCase()}/value',
      ],
    ];
    for (final path in candidates) {
      if (await File(path).exists()) {
        _valuePath = path;
        _activeScheme ??= 'path($path)';
        await _trySetDirectionSibling(path, 'out');
        lwsTrace('GPIO $id: using $path');
        return true;
      }
    }

    final linux = _cfg.fallbackLinuxGpio;
    if (linux == null) {
      debugPrint('GPIO $id: no path and no fallback_linux_gpio');
      return false;
    }

    final export = File('/sys/class/gpio/export');
    final valuePath = '/sys/class/gpio/gpio$linux/value';
    final valueFile = File(valuePath);
    if (!await valueFile.exists()) {
      try {
        await export.writeAsString('$linux');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        debugPrint('GPIO $id: export $linux failed: $e');
      }
    }
    if (await valueFile.exists()) {
      final direction = File('/sys/class/gpio/gpio$linux/direction');
      try {
        await direction.writeAsString('out');
      } catch (e) {
        debugPrint('GPIO $id: direction out failed: $e');
      }
      _valuePath = valuePath;
      _activeScheme ??= 'sysfs(linux=$linux)';
      lwsTrace('GPIO $id: using $valuePath');
      return true;
    }

    debugPrint(
      'GPIO $id: no backend (tried ${candidates.join(", ")}, '
      'sysfs linux=$linux)',
    );
    return false;
  }

  Future<void> _trySetDirectionSibling(
    String valuePath,
    String direction,
  ) async {
    final dirPath = valuePath.replaceFirst(RegExp(r'/value$'), '/direction');
    final file = File(dirPath);
    if (await file.exists()) {
      try {
        await file.writeAsString(direction);
      } catch (_) {}
    }
  }

  bool _physicalHigh(bool logicalHigh) =>
      _defaults.activeLow ? !logicalHigh : logicalHigh;

  @override
  Future<void> set(bool high) async {
    if (!_capabilities.setLevel) {
      throw const HalUnsupportedException('gpio set_level not advertised');
    }
    if (!await _ensureBackend()) {
      return;
    }
    final path = _valuePath!;
    final physical = _physicalHigh(high);
    try {
      await File(path).writeAsString(physical ? '1' : '0');
      _onLogicalSet(id, high);
    } catch (e) {
      debugPrint('GPIO $id: write $path failed: $e');
    }
  }

  @override
  Future<bool> get() async {
    if (!_capabilities.readLevel) {
      throw const HalUnsupportedException('gpio read_level not advertised');
    }
    if (!await _ensureBackend()) {
      throw const HalIoException('gpio backend unavailable');
    }
    final raw = (await File(_valuePath!).readAsString()).trim();
    final physicalHigh = raw == '1';
    return _defaults.activeLow ? !physicalHigh : physicalHigh;
  }

  @override
  Future<void> setMode(GpioLineMode mode, {bool force = false}) async {
    // Idempotent only after a real apply. [_mode] starts null so the first
    // Off still drives the pin (boot may leave indicators HIGH).
    // Re-entering blink would cancel the timer and force ON → looks steady.
    // [force] is for boot reset: always rewrite the pin.
    if (!force && _mode == mode) {
      return;
    }
    _cancelBlink();
    switch (mode) {
      case GpioLineMode.off:
        await set(false);
      case GpioLineMode.steady:
        if (!_capabilities.setLevel) {
          throw const HalUnsupportedException('gpio set_level not advertised');
        }
        await set(true);
      case GpioLineMode.blink:
        if (!_capabilities.blink) {
          throw const HalUnsupportedException('gpio blink not advertised');
        }
        _blinkPhaseHigh = true;
        await set(true);
        _scheduleBlinkTick();
    }
    _mode = mode;
  }

  void _scheduleBlinkTick() {
    final onMs = _defaults.blinkOnMs;
    final offMs = _defaults.blinkOffMs;
    final delayMs = _blinkPhaseHigh ? onMs : offMs;
    _blinkTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_onBlinkTick());
    });
  }

  Future<void> _onBlinkTick() async {
    if (_mode != GpioLineMode.blink) {
      return;
    }
    _blinkPhaseHigh = !_blinkPhaseHigh;
    await set(_blinkPhaseHigh);
    if (_mode == GpioLineMode.blink) {
      _scheduleBlinkTick();
    }
  }

  void _cancelBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  Future<void> dispose() async {
    _cancelBlink();
    await set(false);
    _mode = GpioLineMode.off;
  }
}
