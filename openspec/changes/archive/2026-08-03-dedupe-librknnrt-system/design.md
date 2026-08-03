## Context

Both copies are byte-identical (`librknnrt version: 2.3.0`, stamp `sdk-rknpu2`). `/usr/lib` is already required by P1 / `rknn_server` / `env-verify`. `/opt/hmi/lib` exists only because `build-ai.sh` `copy_so`s RKNN beside OpenCV for App-owned companions.

## Goals / Non-Goals

**Goals:**

- Single on-device `librknnrt.so` at `/usr/lib`.
- Daemon still links `librknnrt.so` at build time against `prebuilt/rknn-rt`; at runtime uses the system library.
- Clear leftovers from incremental rootfs and `push-app`.

**Non-Goals:**

- Moving OpenCV out of `/opt/hmi/lib`.
- Changing `rknn_server` placement.
- Bumping RKNN version (stay on current SDK 2.3.0 pin).

## Decisions

### D1 — Drop RKNN from `build-ai` companion stage only

Keep `-DRKNN_RT_LIB=…` for link; remove `copy_so "$RKNN_SO"`. OpenCV stays App-bundled.

### D2 — `LD_LIBRARY_PATH=/opt/hmi/lib` unchanged

OpenCV still needs it. Without a local `librknnrt.so`, the dynamic linker falls through to `/usr/lib` (standard search after `LD_LIBRARY_PATH`).

### D3 — Explicit purge on post-build + push-app apply

Same class as JIT orphans: additive sync leaves stale files. `rm -f /opt/hmi/lib/librknnrt.so*` in post-build and after companion copy in `push-app-apply-and-restart.sh`.

### D4 — Verify gate

`verify-rootfs-overlay`: FAIL if `/opt/hmi/lib/librknnrt.so` exists; keep FAIL if `/usr/lib/librknnrt.so` missing.

## Risks / Trade-offs

- **[Risk]** Board with only App push and no `/usr/lib` RKNN (broken image) → Mitigation: already gated by env-verify / rootfs verify; product always ships `/usr/lib`.
- **[Risk]** Stale `/opt/hmi/lib/librknnrt.so` after push-app without purge → Mitigation: D3.

## Migration Plan

1. Land script/overlay changes; delete tracked overlay copy if present.
2. `make build-ai` (refresh prebuilt without RKNN `.so`).
3. `make build-app` + `make push-app` (clears board `/opt/hmi/lib` copy).
4. `make apply-overlay` + `make build-rootfs` once to purge baked target leftover.

## Open Questions

- None.
