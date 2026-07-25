import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lws_hmi/platform/os_paths.dart';

/// Tmpfs marker so boot self-check runs at most once per system boot
/// (`/run/hmi/boot-self-check-done`, cleared on reboot).
abstract final class BootSelfCheckBootMarker {
  static const fileName = 'boot-self-check-done';

  /// Test override; when null, uses [OsPaths.runHmi]/[fileName].
  static String? pathOverrideForTest;

  static String get path =>
      pathOverrideForTest ?? '${OsPaths.runHmi}/$fileName';

  static bool exists() {
    try {
      return File(path).existsSync();
    } catch (e) {
      debugPrint('boot-self-check: marker exists check failed: $e');
      return false;
    }
  }

  /// Best-effort create; soft-fails on I/O errors (degrades to once-per-process).
  static void mark() {
    try {
      final file = File(path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('1\n', flush: true);
    } catch (e) {
      debugPrint('boot-self-check: marker write failed: $e');
    }
  }

  /// Test helper: delete marker if present.
  static void clearForTest() {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  /// Test helper: reset path override and clear marker at previous path.
  static void resetForTest() {
    clearForTest();
    pathOverrideForTest = null;
  }
}
