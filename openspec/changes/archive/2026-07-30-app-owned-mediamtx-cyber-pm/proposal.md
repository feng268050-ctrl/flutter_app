## Why

MediaMTX (~44 MiB) is an IPC-product RTSP fan-out, not a shared OS service. Shipping it in the common rootfs wastes storage for future Apps that do not need cameras. Child-process supervision (MediaMTX now, AI daemon later) should live in a reusable path package so every product HMI can share one spawn/drain/restart contract.

## What Changes

- **BREAKING (rootfs):** Remove `/usr/bin/mediamtx`, `mediamtx.service`, and `render-mediamtx-config.sh` from the rootfs overlay; drop `lws_hmi_mediamtx` from the product defconfig include and rootfs `check-prebuilt` gate.
- Introduce path package **`packages/cyber_pm`** (`ProcessSupervisor`, `RestartPolicy`, log drain → parent stdout / hmi journal).
- Ship MediaMTX under **`/opt/hmi/bin/mediamtx`** via `make build-app` (from `prebuilt/mediamtx/`); Dart writes `/run/hmi/mediamtx.yaml`.
- Rewrite `LinuxIpCameraMediaMtxRelay` to use `cyber_pm` instead of `systemctl`.

## Capabilities

### New Capabilities

- `cyber-pm`: Reusable Dart process supervisor — spawn, stop, restart policies, prefixed log drain.
- `app-owned-mediamtx`: Product MediaMTX packaging under `/opt/hmi/bin`, Dart config writer, App-supervised lifecycle.

### Modified Capabilities

- `hmi-systemd-boot`: Retire mediamtx.service disable/boot-verify expectations tied to the old unit.
- `buildroot-lws-hmi-image`: MediaMTX is no longer a rootfs-overlay / defconfig fragment runtime dependency.

## Impact

- App: `ip_camera_mediamtx_relay`, new config writer, `pubspec` path dep on `cyber_pm`.
- Build: `hmi-bundle-common` / `build-app` copy prebuilt binary; `build-mediamtx` no longer syncs overlay.
- Overlay / verify / README / measure scripts that assume `systemctl … mediamtx` or `/usr/bin/mediamtx`.
- Out of scope: AI daemon binary/IPC; GStreamer/MPP move; non-root HMI.
