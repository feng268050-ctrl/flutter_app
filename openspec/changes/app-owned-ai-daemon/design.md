## Context

lws-ui hosts AI in `native/lensinspector` and ships `lws_ai_daemon` as an App child over Unix sockets (not systemd). lws-hmi already has RKNPU runtime in rootfs, OpenCV sources via `make fetch-opencv`, and App-owned MediaMTX via `cyber_pm` + `/opt/hmi/bin`. P3.3 brings the same AI product path to Linux; business overlay UI stays in P4.

## Goals / Non-Goals

**Goals:**
- Vendor C++ into `native/lws_ai` and cross-build Linux aarch64 `lws_ai_daemon`.
- Package under `/opt/hmi` via `build-app`; supervise with `cyber_pm`.
- Smoke: cold-start spawn, `daemon_ready`, `ping`/`pong` on `/run/hmi/ai/*.sock`.

**Non-Goals:**
- systemd / rootfs AI binary.
- In-process Flutter FFI `libai.so` product path.
- P4 AI Vision overlays, full laser/AI-assist cmd surface, stream-detect product wiring.
- Android APK AI packaging inside this repo.
- Git submodule sharing with lws-ui (vendor copy; sync manually).

## Decisions

1. **Tree at `native/lws_ai`**  
   Mirrors lws-ui `native/lensinspector` renamed for product clarity. Not a Dart package and not a Buildroot package — CMake + host scripts only.

2. **`make build-ai` → `prebuilt/ai/linux-arm64/`**  
   Same pattern as MediaMTX: stamp + binary (+ companion `.so` files). `hmi_bundle_install_ai` copies to `$DEST/bin/lws_ai_daemon` and `$DEST/lib/`.

3. **Cross-build OpenCV → `prebuilt/opencv/linux-arm64/`**  
   Sources already fetched to `.cache/opencv/`. AI CMake needs an aarch64 OpenCV install dir (`OPENCV_PATH`). Build once; link daemon against it. RKNN from existing `prebuilt/rknn-rt`.

4. **Docker `linux/amd64` + Buildroot/SDK toolchain on macOS**  
   Align with other arm64 host builds (`build-mediamtx`, `build-umtprd`). Prefer `scripts/docker-run.sh` / existing toolchain export when present.

5. **Minimal Dart `AiDaemonSupervisor`**  
   Prepare `/run/hmi/ai` and `/var/lib/hmi/ai`, spawn `/opt/hmi/bin/lws_ai_daemon` with argv for workdir/sockets, `cyber_pm` `onFailure` restart, wait for `daemon_ready`, expose ping. Non-fatal if binary missing (smoke / boards without AI prebuilt).

6. **Socket defaults via argv**  
   Override Android `{files}/ai_daemon/` with `/run/hmi/ai/cmd.sock` and `evt.sock` at spawn for testability.

## Risks / Trade-offs

- **[Risk] OpenCV cross-build is heavy / flaky on macOS Docker** → Cache `prebuilt/opencv`; document `FORCE=1` rebuild; keep stamp checks in `check-prebuilt` only when AI build is requested (or soft-gate like other optional runtime deps).
- **[Risk] Daemon CMake still Android-centric (`log`, NDK)** → Linux branch: drop `log`, enable `BUILD_LWS_AI_DAEMON` for non-Android, set `RPATH=$ORIGIN/../lib`.
- **[Risk] Child dies with HMI** → Same as MediaMTX: `hmi.service` restarts App which re-spawns daemon; `cyber_pm` covers child-only crashes.
- **[Trade-off] Vendor copy drifts from lws-ui** → Accept for P3.3; document sync from `lws-ui/native/lensinspector` when pulling algorithm fixes.

## Migration Plan

1. Land OpenSpec + `native/lws_ai` + build scripts.
2. `make build-opencv` + `make build-ai` + `make build-app` + `make push-app`.
3. Board smoke: process under HMI, socket ping.
4. No rootfs upgrade required for the daemon binary (RKNPU already on device).

## Open Questions

None — decisions locked in the implementation plan.
