import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _ScreenshotNative = Int32 Function(
  Pointer<Utf8> outDir,
  Int32 rotateDeg,
  Int32 qFactor,
);
typedef _ScreenshotDart = int Function(
  Pointer<Utf8> outDir,
  int rotateDeg,
  int qFactor,
);

typedef _RecordStartNative = Int32 Function(
  Pointer<Utf8> outDir,
  Int32 fps,
  Int32 scalePct,
  Int32 rotateDeg,
  Int32 audio,
);
typedef _RecordStartDart = int Function(
  Pointer<Utf8> outDir,
  int fps,
  int scalePct,
  int rotateDeg,
  int audio,
);

typedef _VoidNative = Int32 Function();
typedef _VoidDart = int Function();

typedef _StatusNative = Int32 Function(Pointer<Utf8> buf, IntPtr buflen);
typedef _StatusDart = int Function(Pointer<Utf8> buf, int buflen);

typedef _CleanupNative = Int32 Function(Pointer<Utf8> path);
typedef _CleanupDart = int Function(Pointer<Utf8> path);

/// FFI bindings to `libhmi_capture.so` (rootfs `/usr/lib`).
final class CaptureNative {
  CaptureNative._(this._lib)
      : screenshot = _lib
            .lookup<NativeFunction<_ScreenshotNative>>('hmi_capture_screenshot')
            .asFunction(),
        recordStart = _lib
            .lookup<NativeFunction<_RecordStartNative>>(
              'hmi_capture_record_start',
            )
            .asFunction(),
        recordStop = _lib
            .lookup<NativeFunction<_VoidNative>>('hmi_capture_record_stop')
            .asFunction(),
        status = _lib
            .lookup<NativeFunction<_StatusNative>>('hmi_capture_status')
            .asFunction(),
        cleanup = _lib
            .lookup<NativeFunction<_CleanupNative>>('hmi_capture_cleanup')
            .asFunction();

  final DynamicLibrary _lib;

  final _ScreenshotDart screenshot;
  final _RecordStartDart recordStart;
  final _VoidDart recordStop;
  final _StatusDart status;
  final _CleanupDart cleanup;

  static CaptureNative? _instance;

  /// Open the shared library once. Returns null on host/stub or missing .so.
  static CaptureNative? tryOpen() {
    if (_instance != null) {
      return _instance;
    }
    if (!Platform.isLinux) {
      return null;
    }
    for (final name in const [
      'libhmi_capture.so',
      '/usr/lib/libhmi_capture.so',
    ]) {
      try {
        _instance = CaptureNative._(DynamicLibrary.open(name));
        return _instance;
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
