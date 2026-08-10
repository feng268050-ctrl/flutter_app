import 'dart:async';

import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/logical_line.dart';

enum LedMode { off, steady, blink }

/// Multi-channel status LED bank (channel set from config).
abstract class StatusLedBank {
  String get id;

  List<String> get channelIds;

  Future<void> setMode(String channelId, LedMode mode, {bool force = false});

  LedMode modeOf(String channelId);

  Future<bool> isOn(String channelId);

  Future<void> dispose();
}

final class StatusLedBankImpl implements StatusLedBank {
  StatusLedBankImpl({
    required this.id,
    required Map<String, LogicalGpioLine> channels,
    required this.blinkOnMs,
    required this.blinkOffMs,
    required void Function(String lineId, bool logicalHigh) onLogicalSet,
    required bool allowBlink,
    required bool allowSet,
  })  : _channels = channels,
        _onLogicalSet = onLogicalSet,
        _allowBlink = allowBlink,
        _allowSet = allowSet;

  @override
  final String id;

  final Map<String, LogicalGpioLine> _channels;
  final int blinkOnMs;
  final int blinkOffMs;
  final void Function(String lineId, bool logicalHigh) _onLogicalSet;
  final bool _allowBlink;
  final bool _allowSet;

  final Map<String, LedMode?> _modes = {};
  final Map<String, Timer?> _blinkTimers = {};
  final Map<String, bool> _blinkPhaseHigh = {};

  @override
  List<String> get channelIds => _channels.keys.toList(growable: false);

  LogicalGpioLine _line(String channelId) {
    final line = _channels[channelId];
    if (line == null) {
      throw HalNotFoundException('status led channel not found: $channelId');
    }
    return line;
  }

  @override
  LedMode modeOf(String channelId) => _modes[channelId] ?? LedMode.off;

  @override
  Future<bool> isOn(String channelId) => _line(channelId).getLogical();

  Future<void> _set(String channelId, bool high) async {
    if (!_allowSet) {
      throw const HalUnsupportedException('gpio set_level not advertised');
    }
    final line = _line(channelId);
    await line.setLogical(high);
    _onLogicalSet(channelId, high);
    _onLogicalSet('$id/$channelId', high);
  }

  void _cancelBlink(String channelId) {
    _blinkTimers[channelId]?.cancel();
    _blinkTimers[channelId] = null;
  }

  @override
  Future<void> setMode(
    String channelId,
    LedMode mode, {
    bool force = false,
  }) async {
    _line(channelId); // validate
    if (!force && _modes[channelId] == mode) {
      return;
    }
    _cancelBlink(channelId);
    switch (mode) {
      case LedMode.off:
        await _set(channelId, false);
      case LedMode.steady:
        await _set(channelId, true);
      case LedMode.blink:
        if (!_allowBlink) {
          throw const HalUnsupportedException('gpio blink not advertised');
        }
        _blinkPhaseHigh[channelId] = true;
        await _set(channelId, true);
        _scheduleBlinkTick(channelId);
    }
    _modes[channelId] = mode;
  }

  void _scheduleBlinkTick(String channelId) {
    final phaseHigh = _blinkPhaseHigh[channelId] ?? true;
    final delayMs = phaseHigh ? blinkOnMs : blinkOffMs;
    _blinkTimers[channelId] = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_onBlinkTick(channelId));
    });
  }

  Future<void> _onBlinkTick(String channelId) async {
    if (_modes[channelId] != LedMode.blink) return;
    final next = !(_blinkPhaseHigh[channelId] ?? true);
    _blinkPhaseHigh[channelId] = next;
    await _set(channelId, next);
    if (_modes[channelId] == LedMode.blink) {
      _scheduleBlinkTick(channelId);
    }
  }

  @override
  Future<void> dispose() async {
    for (final id in _channels.keys.toList()) {
      _cancelBlink(id);
      try {
        await _set(id, false);
      } catch (_) {}
      _modes[id] = LedMode.off;
    }
    // Logical lines are owned by [GpioHal] shared map.
    _channels.clear();
  }
}
