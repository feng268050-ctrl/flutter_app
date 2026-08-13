import 'package:flutter/foundation.dart';

/// Chatty I/O traces (Modbus frames, backlight steps, audio chatter).
///
/// Off by default even in debug — debugPrint to journal/SSH slows the HMI.
/// Enable: `--dart-define=CYBER_HAL_TRACE=true`
const bool kCyberHalTrace = bool.fromEnvironment(
  'CYBER_HAL_TRACE',
  defaultValue: false,
);

void lwsTrace(String message) {
  if (kCyberHalTrace) {
    debugPrint(message);
  }
}
