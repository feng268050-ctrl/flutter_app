import 'dart:async';

import 'package:cyber_hal/src/gpio/logical_line.dart';

enum EncoderStepDirection { clockwise, counterClockwise }

final class EncoderStep {
  const EncoderStep(this.direction, {required this.at});

  final EncoderStepDirection direction;
  final DateTime at;
}

/// Quadrature rotary encoder with software debounce.
abstract class RotaryEncoder {
  String get id;

  Stream<EncoderStep> get steps;

  Future<void> dispose();
}

final class RotaryEncoderImpl implements RotaryEncoder {
  RotaryEncoderImpl({
    required this.id,
    required LogicalGpioLine a,
    required LogicalGpioLine b,
    required this.debounceMs,
    this.invert = false,
  })  : _a = a,
        _b = b {
    _subA = _a.logicalLevels.listen((_) => _onEdge());
    _subB = _b.logicalLevels.listen((_) => _onEdge());
    unawaited(_seed());
  }

  @override
  final String id;

  final LogicalGpioLine _a;
  final LogicalGpioLine _b;
  final int debounceMs;
  final bool invert;

  final _controller = StreamController<EncoderStep>.broadcast();
  StreamSubscription<bool>? _subA;
  StreamSubscription<bool>? _subB;

  int _lastEncoded = 0;
  int _accum = 0;
  DateTime? _lastStepAt;

  // Standard Gray-code transition table (prev<<2|curr) → delta -1/0/+1
  static const _table = <int, int>{
    0x1: -1,
    0x2: 1,
    0x4: 1,
    0x7: -1,
    0x8: -1,
    0xb: 1,
    0xd: 1,
    0xe: -1,
  };

  @override
  Stream<EncoderStep> get steps => _controller.stream;

  Future<void> _seed() async {
    try {
      final a = await _a.getLogical();
      final b = await _b.getLogical();
      _lastEncoded = (a ? 2 : 0) | (b ? 1 : 0);
    } catch (_) {}
  }

  void _onEdge() {
    unawaited(_handleEdge());
  }

  Future<void> _handleEdge() async {
    bool a;
    bool b;
    try {
      a = await _a.getLogical();
      b = await _b.getLogical();
    } catch (_) {
      return;
    }
    final encoded = (a ? 2 : 0) | (b ? 1 : 0);
    final key = (_lastEncoded << 2) | encoded;
    final delta = _table[key] ?? 0;
    _lastEncoded = encoded;
    if (delta == 0) return;

    _accum += invert ? -delta : delta;
    // Full detent typically 4 Gray transitions.
    if (_accum.abs() < 4) return;

    final now = DateTime.now();
    final last = _lastStepAt;
    if (last != null &&
        now.difference(last).inMilliseconds < debounceMs) {
      _accum = 0;
      return;
    }
    _lastStepAt = now;

    final dir = _accum > 0
        ? EncoderStepDirection.clockwise
        : EncoderStepDirection.counterClockwise;
    _accum = 0;
    if (!_controller.isClosed) {
      _controller.add(EncoderStep(dir, at: now));
    }
  }

  @override
  Future<void> dispose() async {
    await _subA?.cancel();
    await _subB?.cancel();
    await _controller.close();
    // Logical lines owned by [GpioHal].
  }
}
