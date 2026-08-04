## Why

`/usr/libexec/hmi/` became a catch-all for board helpers, including scripts that **cyber_hal** (and host identity tooling) own—product identity, serial resolution, secrets-seal—while the directory name implies Flutter/`hmi.service` ownership. That naming mismatch makes ownership and reviews harder, especially after Vendor Storage identity landed under `hmi/`. We should split a clear **`/usr/libexec/hal/`** tier now, while the identity helpers are still new and cheap to move.

## What Changes

- **BREAKING (on-device path):** Relocate HAL-owned helpers from `/usr/libexec/hmi/` to **`/usr/libexec/hal/`** (at least product identity read/write + ID map, `read-device-serial`, and `secrets-seal` / related CA helper if co-located).
- Update `post-build.sh` `/usr/bin` symlinks (`read-serial`, `read-identity`, `write-identity`, …) to target the new paths.
- Update HAL defaults, OEM/`board_profile` helper paths, and host scripts that hardcode `/usr/libexec/hmi/…` for those tools.
- Document the split in `AGENTS.md` / `os-path-layout`: **`hal`** = platform/HAL helpers; **`hmi`** = UI launch, App push/debug, A/B/USB gadget, compose orchestration that remain App/boot-adjacent.
- Optional short-lived compatibility symlinks under old `hmi/` paths MAY be used for one image cycle; ship policy prefers hard cut + rootfs upgrade (no dual long-term homes).

## Capabilities

### New Capabilities

- _(none — this extends existing path-layout ownership)_

### Modified Capabilities

- `os-path-layout`: Add `/usr/libexec/hal/` as a first-class subsystem helper tier; clarify what stays in `/usr/libexec/hmi/` vs moves to `hal/`; remove the prior “relocating into `/usr/libexec/hal/` is NOT required” carve-out for the helpers this change moves.
- `vendor-storage-identity` (active change / future archived baseline): Identity board helpers live under `/usr/libexec/hal/` (operator `/usr/bin/read-identity` / `write-identity` unchanged).

## Impact

- Overlay: move scripts under `rootfs-overlay/usr/libexec/hal/`; `post-build.sh` symlink targets; any systemd/unit/OEM helper that invokes the moved scripts by absolute path.
- `packages/cyber_hal`: default helper paths (`secrets-seal`, any direct libexec paths); tests/board JSON that assert `…/hmi/…`.
- Host: `write-identity.sh` / identity helpers already prefer `/usr/bin`; fix any remaining hardcodes.
- Docs: `AGENTS.md` path convention, `docs/storage-layout.md` / README only if they mention libexec identity paths.
- Does **not** rename `/var/lib/hal` vs `/var/lib/hmi` (already split); does **not** bulk-move UI launch, push-app, USB plug-ssh, or A/B scripts in this change unless they are clearly HAL-only (prefer leave under `hmi/`).
