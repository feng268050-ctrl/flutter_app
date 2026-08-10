import 'dart:async';

import 'package:cyber_hal/src/gpio/logical_line.dart';

/// In-memory line for host tests / stub backend.
final class StubLogicalGpioLine implements LogicalGpioLine {
  StubLogicalGpioLine(this.id, {bool initial = false}) : _high = initial;

  @override
  final String id;

  bool _high;
  final _controller = StreamController<bool>.broadcast();

  /// Test helper: inject a logical level (also used as "hardware" poke).
  void injectLogical(bool high) {
    _high = high;
    if (!_controller.isClosed) {
      _controller.add(high);
    }
  }

  @override
  Future<void> setLogical(bool high) async {
    _high = high;
    if (!_controller.isClosed) {
      _controller.add(high);
    }
  }

  @override
  Future<bool> getLogical() async => _high;

  @override
  Stream<bool> get logicalLevels => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
