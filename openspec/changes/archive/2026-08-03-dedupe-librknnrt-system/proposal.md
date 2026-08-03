## Why

`librknnrt.so` is deployed twice at the same **2.3.0** content: once under `/usr/lib` (`fetch-rknn-rt`) and once under `/opt/hmi/lib` (`build-ai` companion staging). That wastes ~7 MiB on every product rootfs and risks `LD_LIBRARY_PATH=/opt/hmi/lib` shadowing a future system upgrade. Keep a single system copy; the AI daemon loads it via the default linker path.

## What Changes

- `make build-ai` stages OpenCV (and optional yaml-cpp) companions only — **does not** copy `librknnrt.so` into `prebuilt/ai/linux-arm64/lib/`.
- Product `/opt/hmi/lib` MUST NOT contain `librknnrt.so`; daemon continues to `NEEDED: librknnrt.so` and resolves `/usr/lib/librknnrt.so` (OpenCV still via `LD_LIBRARY_PATH=/opt/hmi/lib`).
- Post-build and `push-app` apply paths purge any leftover App-bundled `librknnrt.so`.
- Verify fails if `/opt/hmi/lib/librknnrt.so` is present; `/usr/lib/librknnrt.so` remains required.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `native-lws-ai`: `build-ai` companion staging excludes RKNN runtime `.so` (link-time still uses `prebuilt/rknn-rt`).
- `app-owned-ai-daemon`: companions under `/opt/hmi/lib` are OpenCV (etc.), not `librknnrt.so`; runtime uses system RKNN.
- `buildroot-lws-hmi-image`: product `/opt/hmi` MUST NOT duplicate `librknnrt.so` already provided at `/usr/lib`.

## Impact

- `scripts/build-ai.sh`
- `overlay/.../post-build.sh`
- `overlay/.../push-app-apply-and-restart.sh`
- `scripts/verify-rootfs-overlay.sh`
- Existing overlay/`prebuilt/ai` copies of `librknnrt.so` removed or rebuilt away
- Next: `make build-ai`, `make build-app`, `make push-app` (and `build-rootfs` once to clear baked orphans)
