# cyber_capture

Reusable **screenshot / screen-record** for Flutter seats that own the
patched eLinux embedder: product HMI apps (`*_hmi`) and **OS Settings**
(`app/os_settings`).

## Architecture

- **Native:** `libhmi_capture.so` — eLinux `SurfaceGl` present-hook `glReadPixels` →
  GStreamer `mppjpegenc` / `mpph264enc` (drop-when-behind). Record is video-only
  until a non-hijacking speaker tap exists (`audio=skipped_no_playback_tap`).
- **Dart:** this package — FFI control + `/run/hmi/capture.cmd` watcher
  (same path for HMI and OS Settings; `/run/hmi` is the shared runtime namespace).
- **Host:** `make screenshot` / `make record-screen` write the cmd file and pull
  `/var/lib/hmi/capture/<stamp>/`. Works when **either** seat is foreground.

## Wire into a consumer App

1. `pubspec.yaml`:

```yaml
dependencies:
  cyber_capture:
    path: ../../packages/cyber_capture
```

2. Bootstrap (e.g. in `app.dart` / `os_settings_app.dart` `initState` / dispose).
   `start()` warms GStreamer on a background path so the first shot is fast:

```dart
late final CaptureCommandWatcher _captureWatcher = CaptureCommandWatcher();

// start:
_captureWatcher.start();

// dispose:
unawaited(_captureWatcher.dispose());
```

3. Board must ship patched `flutter-wayland-client` (present-hook) +
   `/usr/lib/libhmi_capture.so` (`make build-hmi-capture` /
   `TOOL=hmi-capture make build-libexec-binaries`, then
   `FORCE=1 make rebuild-flutter-embedded-linux`, rootfs upgrade).

## Command dialect (`/run/hmi/capture.cmd`)

```
screenshot rotate=0 q=80
record-start fps=30 scale=100 rotate=0 audio=0 adev=default
record-stop
cleanup /var/lib/hmi/capture/shot-…
```
