# native/lws_ai — welding AI engine (Linux)

Vendored from lws-ui `native/lensinspector` (renamed). Product path on Linux is the
**App-owned** `lws_ai_daemon` under `/opt/hmi`, supervised by Dart `cyber_pm` — not a
systemd unit and not a rootfs `/usr` binary.

## Build (host / Docker)

From the repo root (macOS uses Docker automatically, same as other arm64 builds):

```text
make fetch-opencv
make fetch-opencv-ximgproc
make fetch-rknn-rt
make build-opencv
make build-ai
```

Outputs:

- `prebuilt/opencv/linux-arm64/` — aarch64 OpenCV install
- `prebuilt/ai/linux-arm64/lws_ai_daemon` (+ companion `.so` under `lib/`)

`make build-app` copies the daemon into `/opt/hmi/bin` and libs into `/opt/hmi/lib`.

## Runtime (board)

```text
/opt/hmi/bin/lws_ai_daemon
/opt/hmi/lib/…
/run/hmi/ai/cmd.sock
/run/hmi/ai/evt.sock
/var/lib/hmi/ai/          # workdir
/userdata/models/         # optional external RKNN models
```

Spawn example (App does this via `AiDaemonSupervisor`):

```text
/opt/hmi/bin/lws_ai_daemon \
  --workdir /var/lib/hmi/ai \
  --sock-dir /run/hmi/ai
```

## Board smoke (offline RKNN)

Demo images live under `assets/img/` (`stain_demo.jpg`, letterboxed `stain_demo_1920x1080.jpg`).
Helpers under `tools/smoke/`. From repo root (USB-SSH / SSH board, HMI running):

```text
make smoke-ai
```

## CMake notes

- Linux builds enable `lws_ai_daemon` (`BUILD_LWS_AI_DAEMON=ON`).
- Shared `libai.so` JNI (`BUILD_LIBAI`) defaults **OFF** on Linux.
- `cmake/linux_compat/android/log.h` shims Android logging for stream/daemon sources.
