# cyber_capture

Reusable **screenshot / screen-record** for product HMI apps (`*_hmi`).

## Architecture

- **Native:** `libhmi_capture.so` — eLinux `SurfaceGl` present-hook `glReadPixels` →
  GStreamer `mppjpegenc` / `mpph264enc` (drop-when-behind).
- **Dart:** this package — FFI control + `/run/hmi/capture.cmd` watcher.
- **Host:** `make screenshot` / `make record-screen` write the cmd file and pull
  `/var/lib/hmi/capture/<stamp>/`.

## Wire into a second `_hmi` App

1. `pubspec.yaml`:

```yaml
dependencies:
  cyber_capture:
    path: ../../packages/cyber_capture
```

2. Bootstrap (e.g. in `app.dart` `initState` / dispose):

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
record-start fps=30 scale=100 rotate=0 audio=0
record-stop
cleanup /var/lib/hmi/capture/shot-…
```
