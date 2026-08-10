## Context

Today `scripts/build-opencv.sh` builds OpenCV with `BUILD_SHARED_LIBS=ON` into `prebuilt/opencv/linux-arm64/`. `scripts/build-ai.sh` links `lws_ai_daemon` against those shared libs and copies every `libopencv_*.so*` into `prebuilt/ai/linux-arm64/lib/` for `/opt/hmi/lib` (rpath `$ORIGIN/../lib`). `librknnrt.so` already stays on the product rootfs at `/usr/lib` only.

Only one process (`lws_ai_daemon`) consumes this OpenCV; dynamic companions mainly add SONAME symlink noise (~24 directory entries, ~19 MiB beside a ~4 MiB daemon).

## Goals / Non-Goals

**Goals:**

- Statically link OpenCV into `lws_ai_daemon` so App AI prebuilt is effectively one binary (RKNN still dynamic/system).
- Stop staging OpenCV `.so` under `prebuilt/ai/.../lib` and `/opt/hmi/lib`.
- Keep existing `BUILD_LIST` module set; no aggressive dead-code / LTO pass.

**Non-Goals:**

- Function-level tree-shake (`--gc-sections`, LTO, shrinking `BUILD_LIST`).
- Static-linking or relocating `librknnrt.so`.
- Changing Android `libai.so` / JNI packaging.
- Putting OpenCV into the shared rootfs `/usr`.

## Decisions

### D1 — OpenCV prebuilt becomes static archives

Change `scripts/build-opencv.sh` to `-DBUILD_SHARED_LIBS=OFF`. Install still lands under `prebuilt/opencv/linux-arm64/` with `OpenCVConfig.cmake`; CMake `find_package(OpenCV)` then prefers `.a`.

**Alternatives considered:** Keep shared OpenCV but only copy `NEEDED` `.so` — reduces file count slightly, still leaves companions and rpath. Rejected; goal is remove OpenCV `.so` noise.

### D2 — Daemon links static OpenCV; drop `.so` stage

`build-ai.sh` continues to point `-DOPENCV_PATH=...`. Remove the `libopencv_*.so*` copy loop (keep optional yaml-cpp `.so` staging only if a shared yaml-cpp appears; prefer static FetchContent as today). After success, `prebuilt/ai/linux-arm64/lib/` SHOULD be empty or absent of `libopencv_*`; may omit `lib/` entirely if nothing else is staged.

Verify with `readelf -d lws_ai_daemon`: no `NEEDED` entry for `libopencv_*`; `librknnrt.so` remains `NEEDED`.

**Alternatives considered:** Vendor a second “fat” target while keeping shared for debug — unnecessary complexity for one consumer.

### D3 — Bundle install stays “copy whatever is under prebuilt/ai/lib”

`hmi_bundle_install_ai` already copies `src_dir/lib/*` if present and skips `librknnrt*`. With an empty/missing `lib/`, bundle installs only `bin/lws_ai_daemon`. No special-case purge required beyond documenting that stale OpenCV `.so` on a board after push may linger until cleaned; prefer push/bundle overwrite that removes orphaned `libopencv_*` when refreshing `/opt/hmi` (if current push does not wipe `lib/`, add a narrow cleanup of `libopencv_*` under dest lib — implementation detail in tasks).

### D4 — No tree-shake / LTO work

Do not add `-ffunction-sections` / `-Wl,--gc-sections` or OpenCV LTO as part of this change. Module list stays as today. Accept a larger single binary roughly on the order of former OpenCV shared total.

### D5 — Stamp / FORCE rebuild

Shared → static is ABI/layout incompatible. Operators MUST `FORCE=1 make build-opencv` then `FORCE=1 make build-ai`. Bump or rewrite prebuilt stamp labels so `prebuilt_ready` does not treat old shared OpenCV as valid for the new link (e.g. stamp id includes `static` or bump version token in `prebuilt_stamp`).

## Risks / Trade-offs

- **[Risk] Static OpenCV link fails (undefined refs / wrong order / PIC)** → Mitigation: ensure `POSITION_INDEPENDENT_CODE` / `-fPIC` on static OpenCV (OpenCV CMake usually sets this); fix link line via OpenCV imported targets; iterate in Docker aarch64 build like today.
- **[Risk] Larger `lws_ai_daemon` binary slows `push-app`** → Mitigation: acceptable; total payload similar to bin+libs today; single file simpler.
- **[Risk] Orphan OpenCV `.so` left on boards** → Mitigation: document cleanup; optionally delete `libopencv_*` in `hmi_bundle_install_ai` / push when installing AI.
- **[Risk] Other future consumers expected shared OpenCV under `prebuilt/opencv`** → Mitigation: today only `build-ai`; document static-only contract in `native/lws_ai/README.md`.
- **Trade-off:** Cannot hot-swap OpenCV `.so` without rebuilding daemon — acceptable for single-product App-owned path.

## Migration Plan

1. Land scripts + docs + OpenSpec.
2. `FORCE=1 make build-opencv`
3. `FORCE=1 make build-ai`
4. Confirm no `libopencv_*` under `prebuilt/ai/linux-arm64/`; `readelf -d` shows no OpenCV `NEEDED`.
5. `make build-app` + `make push-app` (release: also rootfs as needed).
6. Rollback: revert scripts, `FORCE=1` rebuild shared OpenCV + AI, push again.

## Open Questions

- None blocking: orphan `libopencv_*` cleanup on push is preferred but can be a small follow-up if push already replaces the tree wholesale.
