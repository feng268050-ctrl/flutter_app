import 'dart:async';

import 'package:cyber_hal/src/gpio/logical_line.dart';

enum GpioButtonEventKind { pressed, released, longPressed }

final class GpioButtonEvent {
  const GpioButtonEvent(this.kind, {required this.at});

  final GpioButtonEventKind kind;
  final DateTime at;
}

/// Tactile button with debounce and long-press.
abstract class GpioButton {
  String get id;

  Stream<GpioButtonEvent> get events;

  Future<void> dispose();
}

final class GpioButtonImpl implements GpioButton {
  GpioButtonImpl({
    required this.id,
    required LogicalGpioLine line,
    required this.debounceMs,
    required this.longPressMs,
  }) : _line = line {
    _sub = _line.logicalLevels.listen(_onLevel);
  }

  @override
  final String id;

  final LogicalGpioLine _line;
  final int debounceMs;
  final int longPressMs;

  final _controller = StreamController<GpioButtonEvent>.broadcast();
  StreamSubscription<bool>? _sub;

  Timer? _debounceTimer;
  Timer? _longPressTimer;
  bool? _stablePressed;
  bool? _pending;

  @override
  Stream<GpioButtonEvent> get events => _controller.stream;

  void _onLevel(bool high) {
    _pending = high;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: debounceMs), () {
      final pressed = _pending;
      if (pressed == null) return;
      if (_stablePressed == pressed) return;
      _stablePressed = pressed;
      final now = DateTime.now();
      if (pressed) {
        _controller.add(
          GpioButtonEvent(GpioButtonEventKind.pressed, at: now),
        );
        _longPressTimer?.cancel();
        _longPressTimer = Timer(Duration(milliseconds: longPressMs), () {
          if (_stablePressed == true) {
            _controller.add(
              GpioButtonEvent(
                GpioButtonEventKind.longPressed,
                at: DateTime.now(),
              ),
            );
          }
        });
      } else {
        _longPressTimer?.cancel();
        _longPressTimer = null;
        _controller.add(
          GpioButtonEvent(GpioButtonEventKind.released, at: now),
        );
      }
    });
  }

  @override
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _longPressTimer?.cancel();
    await _sub?.cancel();
    await _controller.close();
    // Logical line owned by [GpioHal].
  }
}
