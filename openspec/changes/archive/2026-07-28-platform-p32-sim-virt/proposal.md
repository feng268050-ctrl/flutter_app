## Why

P3.2 / W4 must prove **one OS image** (same kernel `Image` + same `rootfs.img`) can serve multiple board×screen SKUs via **OEM switch**. The guest is not a separate Debian/Buildroot userspace — it boots the device OS under QEMU with `OEM_ID=sim_virt`.

## What Changes

- Keep OEM pack **`sim_virt`**, Linux-in-guest HAL, GPIO LED overlay (sim auto), three-NIC + SSH hostfwd contract.
- **BREAKING (emulator product):** Formal path is **same** `make build-kernel` `Image` + **same** `make build-rootfs` `rootfs.img` + `sim_virt` `oem.img`, launched by **`make emulator` → `qemu-system-aarch64`** (macOS: **qemu-virgl**). Auto-start Flutter via existing `oem-compose` → `hmi.service` → `hmi-launch.sh`.
- Publish bare `Image` next to FITs; kernel fragment for virtio (gpu/net/block/sound/input) on the **same** device kernel build.
- Thin boot path when OEM is sim (skip ynh960 ParamUpdate / lcd helper; Weston on virtio-gpu-gl).
- Emulator working rootfs may be **grown** for debug headroom; device OTA size unchanged.
- **Deprecate as primary:** independent qemu_aarch64 Buildroot rootfs; `make emulator` that only `utmctl start`s an empty UTM VM.

**Out of scope:** RK SoC simulation; sim OTG; x86_64 host; Factory Test; S4 linux-sdk commit; USB Wi‑Fi / closed USB BT product path on emulator (deferred).

## Capabilities

### New Capabilities

- `p32-utm-guest`: same-OS QEMU guest — shared Image/rootfs, OEM `sim_virt`, Linux HAL, auto HMI, product-shaped NICs + ethssh, USB serial passthrough, no OTG. (Capability id kept; host is QEMU, not UTM-required.)

### Modified Capabilities

- `oem-pack`: `sim_virt` pack; emulator mounts oem as second virtio disk; optional `modbus_rtu_device` helper.
- `hal-board-profile` / `dart-hal`: sim → Linux (not Stub).
- `system-status-overlay`: GPIO LED overlay auto on `board_id=sim` only.

## Impact

- Kernel fragment + Image publish; `build-emulator` / `run-emulator` / VirGL setup; rootfs display-init / hmi-launch sim branches; App LED overlay; docs / OpenSpec / Makefile / README colleague steps.
