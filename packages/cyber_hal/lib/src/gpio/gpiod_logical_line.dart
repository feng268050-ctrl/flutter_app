import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart' as gpiod;
import 'package:cyber_hal/src/core/errors.dart';
import 'package:cyber_hal/src/gpio/gpio_config.dart';
import 'package:cyber_hal/src/gpio/logical_line.dart';
import 'package:cyber_hal/src/linux/lws_trace.dart';

/// Character-device line via [flutter_gpiod].
final class GpiodLogicalGpioLine implements LogicalGpioLine {
  GpiodLogicalGpioLine({
    required this.id,
    required GpioLineBinding binding,
    required bool defaultActiveLow,
    required bool asInput,
  })  : _binding = binding,
        _activeLow = binding.activeLow ?? defaultActiveLow,
        _asInput = asInput;

  @override
  final String id;

  final GpioLineBinding _binding;
  final bool _activeLow;
  final bool _asInput;

  gpiod.GpioLine? _line;
  StreamSubscription<gpiod.SignalEvent>? _sub;
  StreamController<bool>? _levels;
  bool _requested = false;

  Future<void> _ensureRequested() async {
    if (_requested && _line != null) return;
    if (!Platform.isLinux) {
      throw const HalIoException('gpiod backend requires Linux');
    }

    final gpiod.FlutterGpiod instance;
    try {
      instance = gpiod.FlutterGpiod.instance;
    } catch (e) {
      throw HalIoException('gpiod unavailable: $e', cause: e);
    }

    final chip = _resolveChip(instance);
    final offset = _binding.offset;
    if (offset == null) {
      throw HalIoException('gpio $id gpiod binding missing offset');
    }
    if (offset < 0 || offset >= chip.lines.length) {
      throw HalIoException(
        'gpio $id offset $offset out of range for ${chip.name} '
        '(${chip.lines.length} lines)',
      );
    }

    final line = chip.lines[offset];
    final activeState =
        _activeLow ? gpiod.ActiveState.low : gpiod.ActiveState.high;

    try {
      if (_asInput) {
        line.requestInput(
          consumer: 'cyber_hal:$id',
          activeState: activeState,
          triggers: const {
            gpiod.SignalEdge.rising,
            gpiod.SignalEdge.falling,
          },
        );
      } else {
        line.requestOutput(
          consumer: 'cyber_hal:$id',
          activeState: activeState,
          initialValue: false,
        );
      }
    } catch (e) {
      throw HalIoException(
        'gpio $id gpiod request failed (line busy or denied): $e',
        cause: e,
      );
    }

    _line = line;
    _requested = true;
    lwsTrace('GPIO $id: gpiod ${chip.name}:$offset');
  }

  gpiod.GpioChip _resolveChip(gpiod.FlutterGpiod instance) {
    final chips = instance.chips.values;
    final name = _binding.chip;
    if (name != null && name.isNotEmpty) {
      for (final chip in chips) {
        if (chip.name == name) return chip;
      }
      throw HalIoException('gpio $id chip not found: $name');
    }
    final label = _binding.chipLabel;
    if (label != null && label.isNotEmpty) {
      for (final chip in chips) {
        if (chip.label == label) return chip;
      }
      throw HalIoException('gpio $id chip label not found: $label');
    }
    throw HalIoException('gpio $id gpiod binding missing chip/chip_label');
  }

  @override
  Future<void> setLogical(bool high) async {
    await _ensureRequested();
    try {
      // With ActiveState.low, flutter_gpiod treats "active" as logical.
      _line!.setValue(high);
      _emit(high);
    } catch (e) {
      debugPrint('GPIO $id: gpiod setValue failed: $e');
      throw HalIoException('gpio $id set failed: $e', cause: e);
    }
  }

  @override
  Future<bool> getLogical() async {
    await _ensureRequested();
    try {
      return _line!.getValue();
    } catch (e) {
      throw HalIoException('gpio $id get failed: $e', cause: e);
    }
  }

  void _emit(bool high) {
    final c = _levels;
    if (c == null || c.isClosed) return;
    c.add(high);
  }

  @override
  Stream<bool> get logicalLevels {
    final existing = _levels;
    if (existing != null) return existing.stream;
    final controller = StreamController<bool>.broadcast(
      onListen: () {
        unawaited(_attachEdges());
      },
      onCancel: () {
        unawaited(_detachEdges());
      },
    );
    _levels = controller;
    return controller.stream;
  }

  Future<void> _attachEdges() async {
    try {
      await _ensureRequested();
      await _sub?.cancel();
      _sub = _line!.onEvent.listen((event) {
        // Rising = becoming active = logical high with ActiveState mapping.
        final high = event.edge == gpiod.SignalEdge.rising;
        _emit(high);
      });
    } catch (e) {
      debugPrint('GPIO $id: gpiod edge listen failed: $e');
    }
  }

  Future<void> _detachEdges() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<void> dispose() async {
    await _detachEdges();
    await _levels?.close();
    _levels = null;
    if (_requested && _line != null) {
      try {
        _line!.release();
      } catch (e) {
        debugPrint('GPIO $id: gpiod release failed: $e');
      }
    }
    _line = null;
    _requested = false;
  }
}
