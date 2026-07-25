## Why

Default production rootfs is **Weston + `flutter-wayland-client`** (AOT `libapp.so`). `make debug-app` still assumes the alternate **flutter-pi** JIT path; on Weston it either blanks `/opt/hmi` or is refused by a host guard. Developers on the default image cannot use breakpoints / hot reload without flashing `build-rootfs-flutter-pi`. Sony eLinux already supports debug via `LD_LIBRARY_PATH` + JIT assets — we only need to wire `hmi-launch` / deploy for `display-stack=weston`.

## What Changes

- Extend board `hmi-launch.sh` so **Weston** payloads with `runtime-mode.json` `mode=debug` start Weston + `flutter-wayland-client` using the cached debug engine (`LD_LIBRARY_PATH` → `/var/lib/hmi/debug-runtime/<ver>/`) and JIT assets (`kernel_blob.bin` + snapshots), not AOT `libapp.so`.
- Ensure debug install places ICU at the eLinux-expected path (`/opt/hmi/data/icudtl.dat`).
- Allow host `debug-app-deploy` (and board `debug-app-apply`) on `display-stack=weston|wayland|elinux` as well as `flutter-pi`; keep clear failures when debug runtime/assets are missing **before** stopping the release HMI.
- Keep flutter-pi debug behavior unchanged; `make push-app` remains the way back to release AOT on either stack.
- Update host docs (`app/README.md`) so P1.5 debug is no longer documented as flutter-pi-only.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `host-debug-hmi`: `make debug-app` / IDE custom-device MUST work on the default Weston image (and continue to work on alternate flutter-pi); requirements that hard-code “starts flutter-pi” become display-stack-aware.

## Impact

- Overlay: `usr/libexec/hmi/hmi-launch.sh`, `debug-app-apply.sh`, `debug-app-run.sh` (log wording / readiness).
- Host: `scripts/debug-app-deploy.sh` (remove/replace Weston refuse), possibly `build-debug-app.sh` / apply for ICU placement; `scripts/tests/debug-app.test.sh`; `app/README.md`.
- No new rootfs packages; no rebuild of `flutter-wayland-client` required if dynamic `libflutter_engine.so` + Sony `LD_LIBRARY_PATH` pattern holds (validate on board).
- Spec `openspec/specs/host-debug-hmi/spec.md` (delta in this change).
