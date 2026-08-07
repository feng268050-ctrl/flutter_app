## Why

`make build-ai` currently stages a pile of OpenCV shared libraries (`libopencv_*.so*` SONAME chains) under `prebuilt/ai/linux-arm64/lib/` and ships them to `/opt/hmi/lib`. OpenCV is only consumed by the single App-owned `lws_ai_daemon`, so dynamic companions add deployment noise without meaningful runtime sharing. Static-link OpenCV into the daemon to leave a single binary (plus system `librknnrt.so`), without pursuing function-level tree-shake / LTO.

## What Changes

- Build OpenCV aarch64 prebuilt as **static libraries** (`BUILD_SHARED_LIBS=OFF`) via `make build-opencv`.
- Link `lws_ai_daemon` against those static OpenCV archives; stop copying `libopencv_*.so*` into `prebuilt/ai/linux-arm64/lib/`.
- Keep **`librknnrt.so` dynamic** on the product rootfs at `/usr/lib` (unchanged from `dedupe-librknnrt-system`).
- Update HMI bundle / docs so App AI packaging no longer expects OpenCV companions under `/opt/hmi/lib`.
- **Out of scope:** function-level `--gc-sections` / LTO “tree-shake”, Android `libai.so` packaging, changing `BUILD_LIST` modules, static-linking RKNN.

## Capabilities

### New Capabilities

- _(none)_

### Modified Capabilities

- `native-lws-ai`: `make build-opencv` produces static OpenCV; `make build-ai` statically links OpenCV into `lws_ai_daemon` and MUST NOT stage OpenCV `.so` companions.
- `app-owned-ai-daemon`: `/opt/hmi` AI install is the daemon binary only for OpenCV (no App-bundled OpenCV `.so`); RKNN remains system `/usr/lib/librknnrt.so`.

## Impact

- `scripts/build-opencv.sh` — shared → static.
- `scripts/build-ai.sh` — drop OpenCV `.so` staging; ensure static link succeeds.
- `scripts/hmi-bundle-common.sh` (`hmi_bundle_install_ai`) — may still copy optional non-OpenCV companions if any; must not require OpenCV `.so`.
- `native/lws_ai/README.md`, AGENTS/README rebuild notes if they mention companion OpenCV libs.
- Prebuilt refresh: **`FORCE=1 make build-opencv`** then **`FORCE=1 make build-ai`** (old shared OpenCV stamp incompatible).
- Board: `make build-app` + `make push-app` (or rootfs bake) to replace `/opt/hmi` AI layout; leftover OpenCV `.so` under `/opt/hmi/lib` are orphans and SHOULD be removed on next bundle/push.
