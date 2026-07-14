import 'dart:io';

import 'package:lws_hmi/device/display_value.dart';

/// Reads board identity used for USB gadget iSerial (`/usr/bin/read-serial`).
class DeviceSnReader {
  const DeviceSnReader({
    this.readSerialPath = '/usr/bin/read-serial',
  });

  final String readSerialPath;

  /// Returns trimmed serial, or [kUnavailableDisplay] on any failure.
  Future<String> read() async {
    try {
      final result = await Process.run(readSerialPath, const <String>[]);
      if (result.exitCode != 0) {
        return kUnavailableDisplay;
      }
      final out = (result.stdout is String)
          ? result.stdout as String
          : result.stdout.toString();
      final sn = out.trim();
      if (sn.isEmpty) {
        return kUnavailableDisplay;
      }
      return sn;
    } catch (_) {
      return kUnavailableDisplay;
    }
  }
}
