import 'dart:async';

import 'package:cyber_hal/src/gpio/gpio_config.dart';

/// Logical (active-high after active_low) GPIO line used by devices.
abstract class LogicalGpioLine {
  String get id;

  Future<void> setLogical(bool high);

  Future<bool> getLogical();

  /// Edge stream of **logical** high/low after polarity mapping.
  /// Stub and gpiod provide events; sysfs may poll.
  Stream<bool> get logicalLevels;

  Future<void> dispose();
}

typedef LogicalLevelListener = void Function(String lineId, bool logicalHigh);

/// Factory for [LogicalGpioLine] from a binding.
abstract class LogicalGpioLineFactory {
  LogicalGpioLine open({
    required String id,
    required GpioLineBinding binding,
    required bool defaultActiveLow,
    required bool asInput,
  });
}
