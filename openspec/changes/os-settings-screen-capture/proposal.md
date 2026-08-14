## Why

`cyber_capture` + present-hook already ship for product HMI (`*_hmi`), but **OS Settings** (`os_settings` seat) does not initialize the package. Operators on the Settings seat cannot use `make screenshot` / `make record-screen` even though the same `flutter-wayland-client` and `libhmi_capture.so` are present. Wire the thin bootstrap so whichever Flutter seat is active honors the same host control plane.

## What Changes

- Add `cyber_capture` path dependency and `CaptureCommandWatcher` bootstrap to `app/os_settings` (same `/run/hmi/capture.cmd` dialect as HMI).
- Extend `hmi-screen-capture` requirements so **any** active Flutter seat that owns the embedder (HMI or OS Settings) SHALL honor host capture commands when the package is started.
- Docs: note that host Make works on either seat; no second cmd path.
- **No** native/embedder changes (already shared).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `hmi-screen-capture`: Require OS Settings (and any future seat using the patched embedder) to initialize `cyber_capture` so host screenshot/record works while that seat is foreground.

## Impact

- `app/os_settings/` pubspec + app bootstrap only.
- Main spec `openspec/specs/hmi-screen-capture/`.
- Host scripts unchanged (still `/run/hmi/capture.cmd`).
- Rebuild: `APP=os_settings make build-app` then `APP=os_settings make push-app` (or rootfs bake).
