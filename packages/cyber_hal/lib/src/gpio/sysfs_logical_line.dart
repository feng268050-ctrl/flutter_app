import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/gpio_config.dart';
import 'package:cyber_hal/src/gpio/logical_line.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Sysfs value-file line (`path` / Innohi label / classic export).
final class SysfsLogicalGpioLine implements LogicalGpioLine {
  SysfsLogicalGpioLine({
    required this.id,
    required GpioLineBinding binding,
    required bool defaultActiveLow,
    this.pollInterval = const Duration(milliseconds: 15),
  })  : _binding = binding,
        _activeLow = binding.activeLow ?? defaultActiveLow;

  @override
  final String id;

  final GpioLineBinding _binding;
  final bool _activeLow;
  final Duration pollInterval;

  String? _valuePath;
  StreamController<bool>? _levels;
  Timer? _pollTimer;
  bool? _lastEmitted;
  bool _directionOut = true;

  bool _physicalHigh(bool logicalHigh) =>
      _activeLow ? !logicalHigh : logicalHigh;

  bool _logicalFromPhysical(bool physicalHigh) =>
      _activeLow ? !physicalHigh : physicalHigh;

  Future<bool> _ensureBackend({required bool asOutput}) async {
    if (_valuePath != null) {
      return true;
    }

    final candidates = <String>[
      if (_binding.path != null && _binding.path!.isNotEmpty) _binding.path!,
      if (_binding.label != null && _binding.label!.isNotEmpty) ...[
        '/sys/class/gpio_innohi/${_binding.label}/value',
        '/sys/class/gpio_innohi/${_binding.label!.toLowerCase()}/value',
      ],
    ];
    for (final path in candidates) {
      if (await File(path).exists()) {
        _valuePath = path;
        if (asOutput) {
          await _trySetDirectionSibling(path, 'out');
        }
        lwsTrace('GPIO $id: using $path');
        return true;
      }
    }

    if (_binding.scheme == GpioBindingScheme.sysfsExport ||
        _binding.fallbackLinuxGpio != null) {
      final linux = _binding.fallbackLinuxGpio;
      if (linux == null) {
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
        if (asOutput) {
          final direction = File('/sys/class/gpio/gpio$linux/direction');
          try {
            await direction.writeAsString('out');
          } catch (e) {
            debugPrint('GPIO $id: direction out failed: $e');
          }
        }
        _valuePath = valuePath;
        lwsTrace('GPIO $id: using $valuePath');
        return true;
      }
    }

    debugPrint(
      'GPIO $id: no sysfs backend (tried ${candidates.join(", ")})',
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

  @override
  Future<void> setLogical(bool high) async {
    _directionOut = true;
    if (!await _ensureBackend(asOutput: true)) {
      return;
    }
    final path = _valuePath!;
    final physical = _physicalHigh(high);
    try {
      await File(path).writeAsString(physical ? '1' : '0');
      _emit(high);
    } catch (e) {
      debugPrint('GPIO $id: write $path failed: $e');
    }
  }

  @override
  Future<bool> getLogical() async {
    if (!await _ensureBackend(asOutput: _directionOut)) {
      throw const HalIoException('gpio backend unavailable');
    }
    final raw = (await File(_valuePath!).readAsString()).trim();
    final physicalHigh = raw == '1';
    return _logicalFromPhysical(physicalHigh);
  }

  void _emit(bool high) {
    final c = _levels;
    if (c == null || c.isClosed) return;
    if (_lastEmitted == high) return;
    _lastEmitted = high;
    c.add(high);
  }

  @override
  Stream<bool> get logicalLevels {
    final existing = _levels;
    if (existing != null) return existing.stream;
    final controller = StreamController<bool>.broadcast(
      onListen: _startPoll,
      onCancel: _maybeStopPoll,
    );
    _levels = controller;
    return controller.stream;
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(_pollOnce());
    });
  }

  void _maybeStopPoll() {
    if (_levels?.hasListener ?? false) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce() async {
    try {
      final high = await getLogical();
      _emit(high);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _levels?.close();
    _levels = null;
  }
}
