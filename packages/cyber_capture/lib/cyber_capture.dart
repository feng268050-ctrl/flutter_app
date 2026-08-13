/// HMI screen capture (screenshot / record) for product `*_hmi` Apps.
///
/// Native path: eLinux `SurfaceGl` present-hook → `libhmi_capture.so` →
/// GStreamer `mppjpegenc` / `mpph264enc`. Dart owns the `/run/hmi/capture.cmd`
/// watcher and FFI control only.
library cyber_capture;

export 'src/capture_controller.dart';
export 'src/capture_command_watcher.dart';
export 'src/capture_paths.dart';
