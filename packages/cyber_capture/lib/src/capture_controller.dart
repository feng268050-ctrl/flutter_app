import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'capture_ffi.dart';
import 'capture_paths.dart';

/// Public capture API used by Apps and the command watcher.
final class CaptureController {
  CaptureController({CaptureNative? native})
      : _native = native ?? CaptureNative.tryOpen();

  final CaptureNative? _native;

  bool get isAvailable => _native != null;

  /// Preload GStreamer/encode worker so the first screenshot is not cold.
  Future<void> warm() async {
    final native = _native;
    if (native == null) {
      return;
    }
    final rc = native.warm();
    if (rc != 0) {
      debugPrint('cyber_capture: warm failed rc=$rc');
    }
  }

  String _stamp() {
    final now = DateTime.now().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<Directory> _stagingDir(String prefix) async {
    final root = Directory(CapturePaths.captureRoot);
    await root.create(recursive: true);
    final dir = Directory('${root.path}/$prefix-${_stamp()}');
    await dir.create(recursive: true);
    return dir;
  }

  /// Arm one-shot still; present-hook encodes on the next frame.
  Future<String?> screenshot({
    int rotateDeg = 0,
    int qFactor = 80,
  }) async {
    final native = _native;
    if (native == null) {
      debugPrint('cyber_capture: libhmi_capture.so unavailable');
      return null;
    }
    final dir = await _stagingDir('shot');
    final rc = using((arena) {
      final p = dir.path.toNativeUtf8(allocator: arena);
      return native.screenshot(p, rotateDeg, qFactor);
    });
    if (rc != 0) {
      debugPrint('cyber_capture: screenshot arm failed rc=$rc');
      return null;
    }
    return dir.path;
  }

  Future<String?> recordStart({
    int fps = 30,
    int scalePct = 100,
    int rotateDeg = 0,
    bool audio = false,
    String audioDev = 'default',
  }) async {
    final native = _native;
    if (native == null) {
      debugPrint('cyber_capture: libhmi_capture.so unavailable');
      return null;
    }
    final dir = await _stagingDir('rec');
    final rc = using((arena) {
      final p = dir.path.toNativeUtf8(allocator: arena);
      final adev = audioDev.toNativeUtf8(allocator: arena);
      return native.recordStart(
        p,
        fps,
        scalePct,
        rotateDeg,
        audio ? 1 : 0,
        adev,
      );
    });
    if (rc != 0) {
      debugPrint('cyber_capture: record-start failed rc=$rc');
      return null;
    }
    return dir.path;
  }

  Future<void> recordStop() async {
    final native = _native;
    if (native == null) {
      return;
    }
    native.recordStop();
  }

  Future<String> status() async {
    final native = _native;
    if (native == null) {
      return 'unavailable';
    }
    try {
      final f = File(CapturePaths.statusFile);
      if (await f.exists()) {
        final lines = await f.readAsLines();
        if (lines.isNotEmpty) {
          return lines.first.trim();
        }
      }
    } catch (_) {}
    return using((arena) {
      final buf = arena<Uint8>(256);
      buf[0] = 0;
      native.status(buf.cast<Utf8>(), 256);
      return buf.cast<Utf8>().toDartString();
    });
  }

  Future<void> cleanup(String path) async {
    final native = _native;
    if (native == null) {
      try {
        await Directory(path).delete(recursive: true);
      } catch (_) {}
      return;
    }
    using((arena) {
      final p = path.toNativeUtf8(allocator: arena);
      native.cleanup(p);
    });
  }
}
