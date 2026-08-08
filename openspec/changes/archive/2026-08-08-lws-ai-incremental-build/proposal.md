## Why

`native/lws_ai` is **first-party product code** (App-owned daemon), not a third-party fetch like MediaMTX/OpenCV/RKNN. Today `make build-ai` follows the prebuilt stamp pattern: once `.lws-prebuilt` exists it **exits without building**, so operators must use `rebuild-ai` / `FORCE=1` for every edit—and that path always wipes the CMake tree. Align with `build-app`: daily **`make build-ai`** is incremental; keep **`make rebuild-ai` / `FORCE=1`** as the repo-wide “force refresh” (wipe cmake + full rebuild), matching other `rebuild-*` targets. Drop stamp; package from the daemon binary in `prebuilt/ai`.

## What Changes

- `make build-ai`: always incremental configure/build/restage (no stamp skip; keep cmake tree).
- `make rebuild-ai` / `FORCE=1 make build-ai`: wipe CMake build dir, then full configure + build + restage (same habit as other `rebuild-*` / `FORCE=1`).
- Fingerprint mismatch also wipes/reconfigures (no separate `CLEAN=` flag).
- Drop `.lws-prebuilt` as AI control plane; `build-app` gates on executable `prebuilt/ai/linux-arm64/lws_ai_daemon`.
- Document: daily `make build-ai` → `make build-app`; `make rebuild-ai` when cache/toolchain is wrong.
- **Out of scope:** static OpenCV, changing OpenCV/RKNN stamp model, Docker cold-start, Android `libai.so`, introducing a `CLEAN=` env for AI.

## Capabilities

### New Capabilities

- _(none)_

### Modified Capabilities

- `native-lws-ai`: incremental `make build-ai`; `rebuild-ai`/`FORCE=1` forces clean rebuild; no stamp-based skip; stage daemon (+ OpenCV companions) into `prebuilt/ai`.
- `app-owned-ai-daemon`: HMI bundle installs AI when the staged daemon binary exists; MUST NOT require `.lws-prebuilt`.

## Impact

- `scripts/build-ai.sh`, `scripts/hmi-bundle-common.sh` (`hmi_bundle_install_ai`).
- Makefile help / `native/lws_ai/README.md` / AGENTS: clarify incremental vs `rebuild-ai` (keep target).
- Configure fingerprint under `.cache/lws_ai/` (gitignored).
- Optional cleanup of manifest/docs mentioning AI `.lws-prebuilt`.
- No board layout change for OpenCV companions / system `librknnrt.so`.
