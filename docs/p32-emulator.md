# P3.2 emulator — same kernel + same rootfs + OEM switch (QEMU)

Goal: prove **one OS** (`Image` from `make build-kernel` + `rootfs.img` from `make build-rootfs`) works for multiple board×screen SKUs by swapping **OEM** only. Guest OEM = `sim_virt`. Device OEM = `ynh960_…`. Flutter still starts via `oem-compose` → `hmi.service` → `hmi-launch.sh`.

**UI scale:** `display.conf` `ui_scale=1.0` is physical 1:1 (no App hard-coded rematch). To approximate the ynh960 panel on QEMU, set **~113%** in OS Settings → Display (or write `ui_scale=1.13` under `/var/lib/hal/display.conf`).

**Host:** Apple Silicon **QEMU** (`make emulator` / qemu-virgl). An earlier plan used UTM; that path is deprecated — see [`p32-utm-guest.md`](p32-utm-guest.md) (redirect only).

OpenSpec: `openspec/changes/archive/2026-07-28-platform-p32-sim-virt`. Plan contract: platform plan §6.3 (three NICs + USB; no OTG).

## Daily commands

**Colleague first-time (full sequence):** see **README.md → Make commands → Daily iteration → P3.2 emulator**.

```bash
make build-app          # if App changed
make build-rootfs       # same rootfs.img as the board (includes emulator .link names)
make build-kernel       # same Image (+ FIT); publishes emulator Image
make build-emulator     # assemble Image + rootfs + sim_virt oem
make emulator           # qemu-system-aarch64 → boot to HMI (ready NIC/USB map)
```

`make build-emulator` builds `OEM_ID=sim_virt` oem if needed.

**Host GPU (required on macOS):** stock `brew install qemu` has OpenGL disabled. Install VirGL QEMU once:

```bash
make setup-emulator-qemu
make fetch-emulator-swgl   # guest Mesa on host disk only (9p) — not baked into rootfs
```

Stop with Ctrl-C, or `make emulator-stop` (kills only the lws-hmi QEMU guest, not Android Studio).

A second `make emulator` auto-stops a previous lws guest (frees `:2222` / `:5580` and the `rootfs.img` lock). Override SSH hostfwd with `EMULATOR_SSH_PORT=`; LAN HTTP (`:5580`) with `EMULATOR_HTTP_PORT=`.

## What `make emulator` prepares (defaults)

Do **not** hand-assemble a half-empty VM. The launcher always sets:

| Guest | Host wiring (default) |
|-------|------------------------|
| `/dev/vda` rootfs.img | same as device |
| `/dev/vdb` → `/oem` | `sim_virt` oem.img |
| `eth0` MAC `52:54:00:12:e0:00` | **IP Camera dedicated link** — bridge host USB-LAN / Ethernet (`EMULATOR_ETH0_IFACE`, auto) |
| `wlan0` MAC `52:54:00:12:a0:00` | Wi‑Fi role — virtio L3 via **Android-like SLIRP** (`10.0.2.16` / gw `10.0.2.2` / DNS `10.0.2.3`); **not** real 802.11 (see Future) |
| `eth1` MAC `52:54:00:12:d0:00` | debug SSH only (not in `net_roles`) |
| `ethssh` (always) | SLIRP hostfwd `localhost:2222`→`:22` and `localhost:5580`→`:5580` |
| virtio-sound | host CoreAudio / Pulse / ALSA (`streams=1` playback); guest needs `CONFIG_SND_VIRTIO=y` |
| virtio-gpu-gl 1536×960 | host VirGL (`qemu-virgl`) |
| USB xHCI | auto-passthrough USB-serial (RS485) + known BT VID:PID; see Modbus note below |

Naming is via rootfs systemd `.link` files (`20-emulator-*.link`). Those MACs never appear on the Rockchip board, so the same rootfs stays safe. Plug the **real IP camera** into the Mac (USB-LAN / Ethernet); guest eth0 is `vmnet-bridged` onto that host iface so `make set-prop CAMERA_IP=…` + properties.ini static path works unchanged. SSH stays on `ethssh` (`make devices` **MODE=EMU**).

### Network modes (`EMULATOR_NET`)

| Value | Behavior |
|-------|----------|
| `auto` (default) | macOS + QEMU with vmnet → `vmnet`; else `user` |
| `vmnet` | eth0/eth1 via vmnet; **wlan0** always Android-like SLIRP `10.0.2.16` |
| `user` | all product NICs SLIRP; **wlan0** Android-like `10.0.2.16`; eth0 still bridged when camera NIC present (unless `EMULATOR_ETH0_BRIDGE=off`) |

`EMULATOR_ETH0_IFACE=en9` forces the host camera NIC (see `networksetup -listallhardwareports`). Auto-picks **USB \* LAN** when present.

**macOS privilege:** Homebrew `qemu-virgl` lacks Apple’s `com.apple.vm.networking` entitlement, so any `vmnet-*` (including camera `vmnet-bridged`) needs root. `make emulator` re-runs QEMU with `sudo -E` and will prompt for your password. Skip the camera bridge (no sudo for eth0) with `EMULATOR_ETH0_BRIDGE=off make emulator` — IP camera will not work.

`EMULATOR_NET=bridge` / Linux `br0` is **not** a documented shortcut — it was easy to misconfigure. On Linux use `user` (default) or pass a working tap/bridge via `EMULATOR_QEMU_EXTRA` after you have verified it.

If sudo is refused / cancelled, QEMU exits — retry and approve, or use `EMULATOR_ETH0_BRIDGE=off`.

### USB (`EMULATOR_USB`)

| Value | Behavior |
|-------|----------|
| `auto` (default) | Discover known USB-serial (FTDI/CP210x/CH340/…) and BT dongles via `ioreg`/`lsusb`; pass each through |
| `off` | xHCI only (no host devices) |
| `vid:pid[,…]` | Explicit list (e.g. `1a86:7523` for WCH CH340 RS485) |

No dongle plugged: launcher **warns** (Modbus/BT will fail) but still boots — other subsystems continue (plan §6.6). Do **not** rely on ad-hoc `EMULATOR_QEMU_EXTRA=-device usb-host…` for the default path.

**Modbus / USB-RS485:** product `modbus.json` uses `/dev/ttyS5` (ynh960 UART). sim OEM helper `modbus_rtu_device=/dev/ttyUSB0` remaps for the QEMU guest. Host dongle must be passed through (`EMULATOR_USB=auto` or `EMULATOR_USB=1a86:7523`); close any macOS app holding `/dev/cu.usbserial-*` before `make emulator`. Guest check: `ls /dev/ttyUSB*`.

Extra QEMU flags only: `EMULATOR_QEMU_EXTRA=…`.

## Artifacts

| Path | Source |
|------|--------|
| `output/firmware/emulator/Image` | Same build as FIT (`make build-kernel`); includes `emulator-virtio.config` (virtio for QEMU — not a ynh960 board feature) |
| `output/firmware/emulator/rootfs.img` | Grown **copy** of device `rootfs.img` to **1536M** (fixed; not an env override) — device OTA stays 600M; emulator needs headroom for `debug-app` (no userdata partition) |
| `output/firmware/emulator/oem.img` | `oem/out/sim_virt/oem.img` |
| `output/firmware/boot.img` | Device FIT (unchanged) |

## QEMU layout

- virtio disk 0 (`/dev/vda`): rootfs.img  
- virtio disk 1 (`/dev/vdb`): oem.img → mounted at `/oem`  
- cmdline: `root=/dev/vda rootfstype=ext4 rw console=ttyAMA0 earlycon lws.emulator=1`  
- Three virtio-net NICs with fixed MACs (above); vmnet adds `ethssh` for SSH hostfwd  
- virtio-sound (host CoreAudio / Pulse / ALSA; playback-only `streams=1`; guest `CONFIG_SND_VIRTIO`)  
- virtio-gpu-gl 1536×960 + virtio keyboard + **virtio-tablet** (absolute pointer, no host mouse grab — Android Emulator–like) for Weston (`Virtual-1`, not board `DSI-1`); OEM `screens/virt` matches QEMU `xres/yres` defaults (~1.2× panel 1280×800 for MacBook HiDPI; panel remains 800×1280)
- Host VirGL: `-device virtio-gpu-gl-pci` + `-display cocoa,gl=es` (qemu-virgl / ANGLE→Metal)  
- Guest Mesa: QEMU 9p tag `lws_gl` → host `prebuilt/emulator-swgl` (mounted at `/run/lws-gl`; **not** in `rootfs.img`)  

## Boot noise that should be gone on emulator

- `usb-otg-role-boot.service` — skipped (`ConditionKernelCommandLine=!lws.emulator=1`; sim has no OTG)  
- `ab-boot-confirm.service` — skipped (no GPT A/B on virtio rootfs)  
- `mainserver.service` / `param-update.service` — skipped (ynh960 MIPI/ParamUpdate)  
- `async-commit` / `pwrkey-poweroff` / `serial-stty` (ttyFIQ0) / `cpu-performance` — skipped via drop-ins  
- `emulator-sshd.service` — **enabled** only when `lws.emulator=1`  
- `emulator-wlan0-dhcp.service` — DHCP on virtio **wlan0** (general LAN; product Wi‑Fi role)  
- `25-emulator-ethssh.network` — DHCP on SSH hostfwd NIC (`ethssh`)  

### Networking / IP Camera on the guest (same topology as product)

| Role | Iface | Emulator behavior |
|------|-------|-------------------|
| **IP Camera link** | `eth0` | Host camera Ethernet bridged in (`vmnet-bridged` / `EMULATOR_ETH0_IFACE`); App applies dedicated `/24` static |
| **Wi‑Fi / general LAN** | `wlan0` | virtio L3 + DHCP; address space matches [Android Emulator Wi‑Fi](https://developer.android.com/studio/run/emulator-networking-address) (`10.0.2.16`, gw/host `10.0.2.2`, DNS `10.0.2.3`; no guest SSID join) |
| **SSH hostfwd** | `ethssh` | `localhost:2222` → guest `:22` (not eth0) |
| **HTTP hostfwd** | `ethssh` | `localhost:5580` → guest `:5580` (HMI `DeviceLocalHttpServer`; Postman) |

Plug the camera into the Mac with a USB-LAN / Ethernet dongle — do **not** use a guest stub. Example: `EMULATOR_ETH0_IFACE=en9 make emulator` (or rely on USB-LAN auto-detect).

### Future (deferred)

- **USB Wi‑Fi passthrough** — guest `wlan0` as real 802.11 (scan / join AP like product); today virtio cannot do that.
- **USB Bluetooth passthrough** — finish product BT path on emulator (dongle → BlueZ); launcher already has optional BT VID:PID hooks, not a closed acceptance item yet.

Hostname: Rockchip `post-hostname.sh` was forcing `$RK_CHIP-buildroot` (`rk3566rk3568-buildroot`). Product post-build + `lws-hostname.service` set `buildroot`.

### Graphics (macOS default: 2D virtio-gpu + guest Mesa)

On macOS, `cocoa,gl=es` + `virtio-gpu-gl` often stays on **Display output is not active** because Weston uses pixman (2D scanout) while the GL display backend only paints GL scanouts. Default `make emulator` therefore uses:

- `-device virtio-gpu-pci` + `-display cocoa` (2D, reliable window)
- Guest Mesa **virtio_gpu** (VirGL) via 9p (`prebuilt/emulator-swgl`) + Mali-free Weston `gl-renderer`/`drm-backend` for Flutter GLES
- Product `flutter-wayland-client` is Mali-linked — emulator uses the Mesa-patched copy under the 9p tree

```bash
make fetch-emulator-swgl          # once: bullseye Mesa + patched flutter client (host disk / 9p)
make apply-overlay
make build-rootfs
make build-emulator
make emulator                     # foreground Terminal (cocoa)
```

`fetch-emulator-swgl` builds an aarch64 `libmali-hook` stub via Docker (`arm64v8/debian:bullseye-slim`). If Docker Hub times out (`context deadline exceeded`), use a mirror:

```bash
EMULATOR_STUB_IMAGE=docker.m.daocloud.io/arm64v8/debian:bullseye-slim make fetch-emulator-swgl
```

Or set Docker Desktop → Docker Engine → `registry-mirrors`, then `docker pull --platform linux/arm64 arm64v8/debian:bullseye-slim` and retry the default `make fetch-emulator-swgl`.

Optional host VirGL: `EMULATOR_GL=host make emulator` (needs `make setup-emulator-qemu`; may still show the placeholder on macOS).

SSH: `ssh -p 2222 root@127.0.0.1` (password `rockchip`) → `journalctl -u hmi.service -b --no-pager`.

## Not the formal path

- Separate Buildroot `qemu_aarch64` userspace rootfs  
- **UTM** empty VM / `utmctl start` only (superseded by QEMU)  
- Hand-installed Debian as “done”  
- Operator-only NIC/USB wiring as the documented default  

Acceptance is **QEMU + same OS artifacts** with the hardware map above.

## Troubleshooting

### `Kernel panic … Attempted to kill init! exitcode=0x0000000b`

Often **not** userspace: Rockchip DRM/`rockchip_sip` issued `smc` into missing ATF on QEMU. Fixed by overlay patches `0006-rockchip-drm-…` and `0007-rockchip-sip-…` — rebuild the shared Image after `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`.

## SSH into guest

- `EMULATOR_NET=user`: `ssh -p 2222 root@127.0.0.1`  
- `EMULATOR_NET=vmnet`: use serial console `ip a` on `eth1` (or product NICs) and SSH to that address from the Mac  
