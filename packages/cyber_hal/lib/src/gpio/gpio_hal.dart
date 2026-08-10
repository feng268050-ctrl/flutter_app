import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/button.dart';
import 'package:cyber_hal/src/gpio/buzzer.dart';
import 'package:cyber_hal/src/gpio/gpio_config.dart';
import 'package:cyber_hal/src/gpio/line_factory.dart';
import 'package:cyber_hal/src/gpio/logical_line.dart';
import 'package:cyber_hal/src/gpio/rotary_encoder.dart';
import 'package:cyber_hal/src/gpio/status_led_bank.dart';
import 'package:cyber_hal/src/gpio/stub_logical_line.dart';
import 'package:cyber_hal/src/profile/board_profile.dart';

export 'package:cyber_hal/src/gpio/button.dart';
export 'package:cyber_hal/src/gpio/buzzer.dart';
export 'package:cyber_hal/src/gpio/rotary_encoder.dart';
export 'package:cyber_hal/src/gpio/status_led_bank.dart'
    show StatusLedBank, LedMode;

/// Fired after a successful logical level write (active-low already applied).
typedef GpioLevelListener = void Function(String lineId, bool logicalHigh);

/// Config-driven GPIO HAL (sysfs and/or gpiod character device).
abstract class GpioHal {
  GpioConfig get config;

  /// Open a named line by config id (v1 lines or device-derived aliases).
  GpioLine openLine(String id);

  StatusLedBank openStatusLed(String id);

  GpioBuzzer openBuzzer(String id);

  GpioButton openButton(String id);

  RotaryEncoder openEncoder(String id);

  /// Host tests: stub line for [id] when using stub bindings; otherwise null.
  StubLogicalGpioLine? debugStubLine(String id);

  /// Observe logical level changes from line/device writes (including blink).
  void addLevelListener(GpioLevelListener listener);

  void removeLevelListener(GpioLevelListener listener);

  Future<void> dispose();

  factory GpioHal.fromConfig(
    GpioConfig config, {
    bool forceStub = false,
  }) =>
      _LinuxGpioHal(config, forceStub: forceStub);

  static Future<GpioHal> fromConfigFile(
    String path, {
    bool forceStub = false,
  }) async {
    final source = await File(path).readAsString();
    return GpioHal.fromConfig(
      GpioConfig.fromJsonString(source),
      forceStub: forceStub,
    );
  }

  static Future<GpioHal> fromAsset({
    required String asset,
    AssetBundle? bundle,
    bool forceStub = false,
  }) async {
    final source = await (bundle ?? rootBundle).loadString(asset);
    return GpioHal.fromConfig(
      GpioConfig.fromJsonString(source),
      forceStub: forceStub,
    );
  }

  static Future<GpioHal> fromProfile(
    BoardProfile profile, {
    AssetBundle? bundle,
    bool forceStub = false,
  }) {
    final asset = profile.resolvedGpioAsset;
    if (asset == null || asset.isEmpty) {
      throw const HalIoException(
        'board profile missing configs.gpio asset path',
      );
    }
    return fromAsset(asset: asset, bundle: bundle, forceStub: forceStub);
  }
}

/// Named GPIO line handle (migration / low-level escape hatch).
abstract class GpioLine {
  String get id;

  Future<void> set(bool high);

  Future<bool> get();

  Future<void> setMode(GpioLineMode mode, {bool force = false});

  GpioLineMode get mode;
}

enum GpioLineMode { off, steady, blink }

final class _LinuxGpioHal implements GpioHal {
  _LinuxGpioHal(this.config, {bool forceStub = false})
      : _forceStub = forceStub,
        _factory = DefaultLogicalGpioLineFactory(forceStub: forceStub);

  @override
  final GpioConfig config;

  final bool _forceStub;
  final DefaultLogicalGpioLineFactory _factory;

  final Map<String, _ManagedGpioLine> _openLines = {};
  final Map<String, StatusLedBankImpl> _statusLeds = {};
  final Map<String, GpioBuzzerImpl> _buzzers = {};
  final Map<String, GpioButtonImpl> _buttons = {};
  final Map<String, RotaryEncoderImpl> _encoders = {};
  final List<GpioLevelListener> _levelListeners = [];
  final Map<String, LogicalGpioLine> _sharedLogical = {};

  @override
  StubLogicalGpioLine? debugStubLine(String id) => _factory.stubLines[id];

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
    for (final listener in List<GpioLevelListener>.of(_levelListeners)) {
      listener(lineId, logicalHigh);
    }
  }

  LogicalGpioLine _openLogical({
    required String id,
    required GpioLineBinding binding,
    required bool asInput,
  }) {
    final existing = _sharedLogical[id];
    if (existing != null) return existing;
    final line = openLogicalLineOrThrow(
      factory: _factory,
      id: id,
      binding: _forceStub
          ? GpioLineBinding(
              scheme: GpioBindingScheme.stub,
              label: binding.label,
              path: binding.path,
              fallbackLinuxGpio: binding.fallbackLinuxGpio,
              chip: binding.chip,
              chipLabel: binding.chipLabel,
              offset: binding.offset,
              activeLow: binding.activeLow,
            )
          : binding,
      defaultActiveLow: config.defaults.activeLow,
      asInput: asInput,
    );
    _sharedLogical[id] = line;
    return line;
  }

  @override
  GpioLine openLine(String id) {
    final existing = _openLines[id];
    if (existing != null) return existing;

    final lineCfg = config.lineById(id);
    if (lineCfg == null) {
      throw HalNotFoundException('gpio line not found: $id');
    }
    final logical = _openLogical(
      id: id,
      binding: lineCfg.binding,
      asInput: false,
    );
    final managed = _ManagedGpioLine(
      id: id,
      logical: logical,
      blinkOnMs: config.defaults.blinkOnMs,
      blinkOffMs: config.defaults.blinkOffMs,
      allowBlink: config.capabilities.blink,
      allowSet: config.capabilities.setLevel,
      allowRead: config.capabilities.readLevel,
      onLogicalSet: _emitLevel,
    );
    _openLines[id] = managed;
    return managed;
  }

  @override
  StatusLedBank openStatusLed(String id) {
    final existing = _statusLeds[id];
    if (existing != null) return existing;
    if (!config.capabilities.allows(GpioDeviceType.statusLed)) {
      throw const HalUnsupportedException('status_led not advertised');
    }
    final device = config.deviceById(id);
    if (device == null ||
        device.type != GpioDeviceType.statusLed ||
        device.statusLed == null) {
      throw HalNotFoundException('status_led not found: $id');
    }
    final channels = <String, LogicalGpioLine>{};
    for (final ch in device.statusLed!.channels) {
      channels[ch.id] = _openLogical(
        id: '$id/${ch.id}',
        binding: ch.binding,
        asInput: false,
      );
    }
    final bank = StatusLedBankImpl(
      id: id,
      channels: channels,
      blinkOnMs: config.defaults.blinkOnMs,
      blinkOffMs: config.defaults.blinkOffMs,
      onLogicalSet: (lineId, high) {
        _emitLevel(lineId, high);
        // Also notify legacy led_* aliases when channel matches.
        final deviceCfg = config.deviceById(id)?.statusLed;
        final slash = lineId.split('/');
        final channelId = slash.length == 2 ? slash[1] : lineId;
        final ch = deviceCfg?.channelById(channelId);
        if (ch != null) {
          for (final alias in ch.aliases) {
            _emitLevel(alias, high);
          }
        }
      },
      allowBlink: config.capabilities.blink,
      allowSet: config.capabilities.setLevel,
    );
    _statusLeds[id] = bank;
    return bank;
  }

  @override
  GpioBuzzer openBuzzer(String id) {
    final existing = _buzzers[id];
    if (existing != null) return existing;
    if (!config.capabilities.allows(GpioDeviceType.buzzer)) {
      throw const HalUnsupportedException('buzzer not advertised');
    }
    final device = config.deviceById(id);
    if (device == null ||
        device.type != GpioDeviceType.buzzer ||
        device.buzzer == null) {
      throw HalNotFoundException('buzzer not found: $id');
    }
    final logical = _openLogical(
      id: id,
      binding: device.buzzer!.line,
      asInput: false,
    );
    final buzzer = GpioBuzzerImpl(id: id, line: logical);
    _buzzers[id] = buzzer;
    return buzzer;
  }

  @override
  GpioButton openButton(String id) {
    final existing = _buttons[id];
    if (existing != null) return existing;
    if (!config.capabilities.allows(GpioDeviceType.button)) {
      throw const HalUnsupportedException('button not advertised');
    }
    final device = config.deviceById(id);
    if (device == null ||
        device.type != GpioDeviceType.button ||
        device.button == null) {
      throw HalNotFoundException('button not found: $id');
    }
    final cfg = device.button!;
    final logical = _openLogical(
      id: id,
      binding: cfg.line,
      asInput: true,
    );
    final button = GpioButtonImpl(
      id: id,
      line: logical,
      debounceMs: cfg.debounceMs ?? config.defaults.buttonDebounceMs,
      longPressMs: cfg.longPressMs ?? config.defaults.buttonLongPressMs,
    );
    _buttons[id] = button;
    return button;
  }

  @override
  RotaryEncoder openEncoder(String id) {
    final existing = _encoders[id];
    if (existing != null) return existing;
    if (!config.capabilities.allows(GpioDeviceType.rotaryEncoder)) {
      throw const HalUnsupportedException('rotary_encoder not advertised');
    }
    final device = config.deviceById(id);
    if (device == null ||
        device.type != GpioDeviceType.rotaryEncoder ||
        device.rotaryEncoder == null) {
      throw HalNotFoundException('rotary_encoder not found: $id');
    }
    final cfg = device.rotaryEncoder!;
    final a = _openLogical(id: '${id}_a', binding: cfg.a, asInput: true);
    final b = _openLogical(id: '${id}_b', binding: cfg.b, asInput: true);
    final enc = RotaryEncoderImpl(
      id: id,
      a: a,
      b: b,
      debounceMs: cfg.debounceMs ?? config.defaults.encoderDebounceMs,
      invert: cfg.invert,
    );
    _encoders[id] = enc;
    return enc;
  }

  @override
  Future<void> dispose() async {
    _levelListeners.clear();
    for (final line in _openLines.values) {
      await line.dispose();
    }
    _openLines.clear();
    for (final bank in _statusLeds.values) {
      await bank.dispose();
    }
    _statusLeds.clear();
    for (final b in _buzzers.values) {
      await b.dispose();
    }
    _buzzers.clear();
    for (final b in _buttons.values) {
      await b.dispose();
    }
    _buttons.clear();
    for (final e in _encoders.values) {
      await e.dispose();
    }
    _encoders.clear();
    for (final line in _sharedLogical.values) {
      try {
        await line.dispose();
      } catch (_) {}
    }
    _sharedLogical.clear();
  }
}

final class _ManagedGpioLine implements GpioLine {
  _ManagedGpioLine({
    required this.id,
    required LogicalGpioLine logical,
    required this.blinkOnMs,
    required this.blinkOffMs,
    required this.allowBlink,
    required this.allowSet,
    required this.allowRead,
    required void Function(String lineId, bool logicalHigh) onLogicalSet,
  })  : _logical = logical,
        _onLogicalSet = onLogicalSet;

  @override
  final String id;

  final LogicalGpioLine _logical;
  final int blinkOnMs;
  final int blinkOffMs;
  final bool allowBlink;
  final bool allowSet;
  final bool allowRead;
  final void Function(String lineId, bool logicalHigh) _onLogicalSet;

  GpioLineMode? _mode;
  Timer? _blinkTimer;
  bool _blinkPhaseHigh = false;

  @override
  GpioLineMode get mode => _mode ?? GpioLineMode.off;

  @override
  Future<void> set(bool high) async {
    if (!allowSet) {
      throw const HalUnsupportedException('gpio set_level not advertised');
    }
    await _logical.setLogical(high);
    _onLogicalSet(id, high);
  }

  @override
  Future<bool> get() async {
    if (!allowRead) {
      throw const HalUnsupportedException('gpio read_level not advertised');
    }
    return _logical.getLogical();
  }

  @override
  Future<void> setMode(GpioLineMode mode, {bool force = false}) async {
    if (!force && _mode == mode) {
      return;
    }
    _cancelBlink();
    switch (mode) {
      case GpioLineMode.off:
        await set(false);
      case GpioLineMode.steady:
        await set(true);
      case GpioLineMode.blink:
        if (!allowBlink) {
          throw const HalUnsupportedException('gpio blink not advertised');
        }
        _blinkPhaseHigh = true;
        await set(true);
        _scheduleBlinkTick();
    }
    _mode = mode;
  }

  void _scheduleBlinkTick() {
    final delayMs = _blinkPhaseHigh ? blinkOnMs : blinkOffMs;
    _blinkTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_onBlinkTick());
    });
  }

  Future<void> _onBlinkTick() async {
    if (_mode != GpioLineMode.blink) return;
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
    try {
      await set(false);
    } catch (_) {}
    _mode = GpioLineMode.off;
    // Do not dispose shared logical here — HAL owns the map.
  }
}
