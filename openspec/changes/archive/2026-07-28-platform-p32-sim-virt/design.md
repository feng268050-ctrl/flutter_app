## Context

W1–W3 delivered OEM compose and ynh960 packs. An earlier W4 draft staged a separate virt Buildroot userspace and UTM-only start — that does **not** validate multi-board support. Correct contract: **identical rootfs + identical kernel Image**, OEM differs (`ynh960_*` vs `sim_virt`).

## Goals / Non-Goals

**Goals:**

- QEMU aarch64 boots device `Image` + `rootfs.img` + `oem/out/sim_virt/oem.img`.
- Same systemd chain starts Flutter (`hmi.service`).
- Same Image still packs into Rockchip FIT for the board.
- virtio (net/block/gpu/console/sound/input) enabled via fragment on that kernel build.
- Host VirGL (macOS qemu-virgl) + guest Mesa 9p; product-shaped NIC/USB map for camera / Modbus / SSH tooling.

**Non-Goals:**

- Separate virt rootfs as the formal guest OS.
- Empty UTM VM as “emulator done”.
- Bit-identical Rockchip FIT boot under QEMU (FIT/U-Boot stay board-only).
- Real 802.11 / closed BT product path on emulator until USB Wi‑Fi / USB BT passthrough (deferred).

## Decisions

### D1 — Same Image, two boot wrappers

Device: FIT (`boot.img`) + RK DT. Emulator: bare `Image` + QEMU `-machine virt` + cmdline `root=/dev/vda` (+ `lws.emulator=1`). One `make build-kernel`.

### D2 — Same rootfs content; emulator may grow the working copy

No second Buildroot userspace. Assemble starts from `output/firmware/rootfs.img`, then **copies and grows** the emulator working image (default **1536M**, `EMULATOR_ROOTFS_SIZE`) so `debug-app` / `push-app` have headroom. Device OTA / GPT slot stays **600M**. Guest has no userdata partition (prefs stay on `/` until a future virtio userdata disk).

### D3 — OEM second disk

QEMU `-drive` oem.img as `/dev/vdb`; `oem-compose` / display-init mount it to `/oem`.

### D4 — Host launcher = QEMU CLI (+ VirGL)

`make emulator` runs `qemu-system-aarch64` from **qemu-virgl** on macOS (`make setup-emulator-qemu`). Stock `brew install qemu` has OpenGL disabled and is not sufficient. Free UTM import is optional, not required for acceptance.

### D5 — Sim boot thinning

No OEM `display-init.sh` ⇒ display-init stub exits 0 after mounting `/oem`. `hmi-launch` uses landscape-friendly Weston transform when `BOARD_ID=sim`; DRM backend stays (virtio-gpu-gl).

### D6 — Network topology (product-shaped)

| Guest | Role |
|-------|------|
| `eth0` | IP camera dedicated link — host USB-LAN/Ethernet via `vmnet-bridged` (`EMULATOR_ETH0_IFACE`) |
| `wlan0` | Product Wi‑Fi role — virtio L3 (`vmnet-shared` / SLIRP); not real 802.11 yet |
| `eth1` | Debug leftover MAC (not in `net_roles`) |
| `ethssh` | SSH hostfwd `localhost:2222` → guest `:22` (`make devices` **MODE=EMU**) |

macOS vmnet needs root → launcher uses `sudo -E` when any vmnet netdev is configured.

### D7 — Pointer and audio

- `virtio-tablet-pci` (absolute) — Android Emulator–like, no mouse grab.
- `virtio-sound-pci` playback-only (`streams=1`) + host CoreAudio/Pulse/ALSA; guest `CONFIG_SND_VIRTIO`.

### D8 — GPIO LED overlay

Visible only when `board_id == sim` (no settings toggle). Lights-only; blink follows HAL `GpioLine.set` via level listener.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| RK kernel panics on virt | `emulator-virtio.config`; patches `0006`/`0007`; iterate cmdline — still no forked rootfs |
| Mali GBM fails | VirGL + 9p Mesa/Weston modules; fail visible if Weston cannot start |
| Owned-tree skips kernel fragments | `apply-overlay` always syncs `overlay/kernel` fragments even when skipping full platform overlay |
| 600M rootfs fills during debug-app | Emulator-only grow + apply uses `mv` not double `cp` |
| Module version mismatch | assemble checks `Image` vs rootfs modules release when possible |

## Migration Plan

1. Realign OpenSpec/docs. ✅
2. Fragment + publish Image; rewrite emulator assemble/run. ✅
3. Rootfs sim thin boots. ✅
4. Accept: QEMU → HMI; FIT+ynh960 OEM still for device. ✅ repo / field smoke optional
5. Archive change when operator smoke + plan W4 status agree. ✅
