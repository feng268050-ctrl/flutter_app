import 'dart:async';

import 'package:cyber_hal/src/gpio/logical_line.dart';

/// GPIO-driven buzzer (on/off + finite beep).
abstract class GpioBuzzer {
  String get id;

  Future<void> setOn(bool on);

  /// Finite beep; cancels any in-progress pattern.
  Future<void> beep({Duration duration = const Duration(milliseconds: 100)});

  Future<void> cancel();

  Future<void> dispose();
}

final class GpioBuzzerImpl implements GpioBuzzer {
  GpioBuzzerImpl({
    required this.id,
    required LogicalGpioLine line,
  }) : _line = line;

  @override
  final String id;

  final LogicalGpioLine _line;
  Timer? _beepTimer;

  @override
  Future<void> setOn(bool on) async {
    _beepTimer?.cancel();
    _beepTimer = null;
    await _line.setLogical(on);
  }

  @override
  Future<void> beep({
    Duration duration = const Duration(milliseconds: 100),
  }) async {
    _beepTimer?.cancel();
    await _line.setLogical(true);
    final completer = Completer<void>();
    _beepTimer = Timer(duration, () {
      unawaited(() async {
        try {
          await _line.setLogical(false);
        } finally {
          if (!completer.isCompleted) completer.complete();
        }
      }());
    });
    await completer.future;
  }

  @override
  Future<void> cancel() async {
    _beepTimer?.cancel();
    _beepTimer = null;
    await _line.setLogical(false);
  }

  @override
  Future<void> dispose() async {
    await cancel();
    // Logical line owned by [GpioHal].
  }
}
