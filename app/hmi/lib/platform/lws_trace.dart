import 'package:flutter/foundation.dart';

/// Chatty I/O traces (Modbus frames, backlight steps, audio chatter).
///
/// Off by default even in debug — debugPrint to journal/SSH slows the HMI.
/// Enable: `--dart-define=LWS_HMI_TRACE=true`
const bool kLwsHmiTrace = bool.fromEnvironment(
  'LWS_HMI_TRACE',
  defaultValue: false,
);

void lwsTrace(String message) {
  if (kLwsHmiTrace) {
    debugPrint(message);
  }
}
