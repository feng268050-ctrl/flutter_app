import 'dart:io';

import 'package:cyber_hal/cyber_hal.dart';
import 'package:flutter/foundation.dart';

/// Camera ICMP reachability for boot self-check (lws-ui ping-only path).
abstract final class BootSelfCheckCameraProbe {
  /// Default IPC address from lws-ui `CameraConfig.DEFAULT_CAMERA_IP`.
  static const defaultCameraIp = '192.168.1.100';

  /// Resolve host from board [helpers] `camera_ip`, else [defaultCameraIp].
  static String? resolveHost(BoardProfile? profile) {
    final fromProfile = profile?.helper(BoardHelperKeys.cameraIp)?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }
    return defaultCameraIp;
  }

  /// Host/macOS/tests without a real camera segment: skip when not Linux.
  static bool isApplicable({
    BoardProfile? profile,
    bool? forceApplicableForTest,
  }) {
    if (forceApplicableForTest != null) {
      return forceApplicableForTest;
    }
    if (!Platform.isLinux) {
      return false;
    }
    final host = resolveHost(profile);
    return host != null && host.isNotEmpty;
  }

  /// ICMP ping with bounded timeout. Returns false on any failure.
  static Future<bool> pingHost(
    String host, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    try {
      final result = await Process.run(
        'ping',
        <String>['-c', '1', '-W', '1', host],
      ).timeout(timeout);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('boot-self-check: camera ping failed: $e');
      return false;
    }
  }
}
