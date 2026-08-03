## Why

After `APP=` multi-app selection, each HMI product bakes a different `/opt/hmi` into rootfs, so a single flat `output/firmware/rootfs.img` can no longer be shared across products the way `boot.img` is. Host upgrade/flash must store and load the matching rootfs (and factory package that embeds it) per `APP`.

## What Changes

- **BREAKING (host paths):** Publish `rootfs.img` under `output/firmware/<APP>/rootfs.img` (default `APP=lws_hmi`), not only the shared firmware root.
- `make build-rootfs` / docker-export: write rootfs artifacts into the APP firmware dir.
- `make upgrade`: load `rootfs.img` from the APP firmware dir; keep shared `boot.img` / `boot_b.img` at `output/firmware/`.
- `make build-img` / `make flash`: consume APP-scoped rootfs and publish/flash `factory.img` under `output/firmware/<APP>/<FACTORY_SKU>/` (migration `update.img` points at default APP + default sku).
- Document `APP=` for build-rootfs / upgrade / flash / build-img in Makefile help, README, AGENTS.

## Capabilities

### New Capabilities

- `per-app-rootfs-artifacts`: Host firmware layout and Make targets resolve rootfs (and factory packages that embed it) by `APP`.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Factory/flash path requirements include APP dimension alongside FACTORY_SKU.
- `host-remote-upgrade` (if present) / ab upgrade host path: upgrade resolves rootfs via APP — check existing specs; add delta under `ab-firmware-slots` or new capability only if needed.

## Impact

- `scripts/docker-export-artifacts.sh`, `scripts/upgrade-remote.sh`, `scripts/build-img.sh`, `scripts/flash-usb.sh`, `scripts/factory-sku.sh` or `scripts/app-select.sh`
- `Makefile`, `AGENTS.md`, `README.md`
- Emulator rootfs copy source path (same APP resolution)
- On-device stream basename remains `rootfs.img` (unchanged)
