# eMMC storage layout (ynh960 product line)

Single GPT for all ynh960/961/962 SKUs. Defined in [`board/parameter-buildroot-fit.txt`](../board/parameter-buildroot-fit.txt); applied on **`make flash`** (full re-partition).

## Partition table

Rockchip `parameter.txt` uses **512-byte sectors**.

| Order | PARTNAME | Size | Mount | Who mounts |
|-------|----------|------|-------|------------|
| boot chain | uboot, misc, boot, recovery, backup | ~178 MiB | — | — |
| system | **rootfs** | **1 GiB fixed** | `/` | kernel (`root=/dev/mmcblk0p6`) / fstab |
| vendor | **oem** | 128 MiB | `/oem` | `ynh960-display-init.sh` |
| factory | private, private1 | 5 MiB each | `/mnt/private*` | display-init |
| user data | **userdata** | **grow** (rest of eMMC) | `/userdata` | display-init (auto `mkfs.ext4` if empty) |

**No `userdata1`.** One growable **`userdata`** partition only.

### Why rootfs is 1 GiB (not 3 GiB)

| Content | Where | Size (product budget) |
|---------|--------|------------------------|
| Buildroot system + libs (P5) | `/` rootfs | **≤ ~500 MiB** in flash image |
| Flutter `/opt/hmi` | `/` rootfs | **≤ ~800 MiB** worst case via `push-app` (typical P5 UI **30–70 MiB**) |
| RKNN models | **`/userdata/models/`** | userdata (not rootfs) |
| OTA `update.img` download | **`/userdata/ota/`** | userdata (not rootfs) |
| PR0 录像 / sqlite | `/userdata/…` | userdata |

**`update.img` whole package ≤ ~600 MiB** (boot + rootfs + misc…) ⇒ **`rootfs.ext2` ~430–550 MiB** today/P5 target.  
**1 GiB partition** ≈ 2× that budget — enough for ext4 metadata and a few `push-app` iterations without repartitioning.

If uncompressed rootfs on device ever approaches **~900 MiB**, bump `0x00200000` → `0x00300000` (1.5 GiB) in parameter and re-flash.

### Typical capacities

| eMMC (nominal) | ~usable | rootfs | userdata (approx.) |
|----------------|---------|--------|---------------------|
| 32 GiB | ~29 GiB | 1 GiB | **~27 GiB** |
| 16 GiB | ~15 GiB | 1 GiB | **~13 GiB** |

`scripts/verify-firmware-partitions.sh` fails the build if `rootfs.img` exceeds the **1 GiB** GPT slot.

## Runtime paths

| Content | Path | Partition |
|---------|------|-----------|
| Buildroot rootfs, `/opt/hmi`, libs | `/` | rootfs |
| LCD/MIPI params (seed) | `/mnt/private1/` | private1 |
| OEM / vendor drop-ins (optional) | `/oem/` | oem |
| **RKNN models** (`*.rknn`, `config.yaml`) | **`/userdata/models/`** | userdata |
| PR0 recording, sqlite, OTA download cache | `/userdata/…` | userdata |
| App config / prefs (P2.3) | **`/userdata/lws-hmi/`** ( `/var/lib/lws-hmi` symlink ) | userdata |
| App config / cache | `/userdata/cfg/` (convention) | userdata |

`/userdata` is **not** in `/etc/fstab`. `param-update.service` runs `ynh960-display-init.sh`, which mounts `PARTLABEL=userdata` → `/userdata`, formats on first boot when empty, then runs **`lws-hmi-prefs-bind.sh`** so `/var/lib/lws-hmi` → `/userdata/lws-hmi`.

## Prefs: flash vs upgrade (P2.3 / P2.4)

Hardware settings (Wi‑Fi, eth0, backlight, orientation, proxy, BT A2DP prefs, …) live under **`/userdata/lws-hmi/`**.

| Operation | What changes | Settings (`/userdata/lws-hmi`) |
|-----------|--------------|--------------------------------|
| **Cold reboot** | nothing on disk | **Keep** — `lws-hmi-settings-restore` re-applies |
| **`make push-app` / `systemctl restart hmi`** | `/opt/hmi` or HMI process only | **Keep** — stacks are outside `hmi.service` cgroup |
| **`make upgrade` (P2.4 A/B)** | inactive **rootfs** slot only | **Keep** — must **not** wipe or rewrite userdata |
| **`make flash`** (RockUSB `update.img`, factory / GPT) | full image path; product **factory reset** | **Must clear** — complete reset after flash |

Notes:

- Rockchip `uf update.img` often **does not** rewrite the grow **userdata** partition by itself. Product policy still requires a **flash-time wipe of prefs** (planned: wipe `/userdata/lws-hmi` and/or factory-reset userdata on first boot after flash). Until that lands, do not assume bare `make flash` already erased Wi‑Fi credentials.
- **P2.4 `make upgrade`** must never format userdata or delete `/userdata/lws-hmi`; that is how OTA keeps operator settings while swapping rootfs A/B.
- RTC clock time is hardware and is unrelated to this prefs tree.

## OTA / remote upgrade

- **P2.4 — A/B dual rootfs**: replace the single 1 GiB `rootfs` GPT slot with **A/B slots** in a later `parameter` revision; inactive-slot write + boot-flag switch + reboot (**no bootloader flash**). Host entry: **`make upgrade`** over USB-SSH or LAN SSH. **userdata (incl. P2.3 prefs) preserved.**
- **P5.8 — product OTA**: UI / cloud (or local) package orchestration on top of the P2.4 slot machinery; two-level updates (app-only vs full system). Staging downloads under **`/userdata/ota/`**.
- **Full `update.img` via `make flash`**: factory / first GPT change / intentional **full reset** (prefs cleared per policy above); not the day-to-day upgrade path after P2.4.

## Changing layout

1. Edit `board/parameter-buildroot-fit.txt`.
2. If rootfs **order** in GPT changes, update `overlay/kernel/rockchip/lws-hmi-ynh960-linux-root.dtsi` (`root=/dev/mmcblk0pN`; currently **p6**).
3. `make apply-overlay` → `make build-kernel` → `make build-img` → **`make flash`** (destructive re-partition).
4. Update this doc and any path references in specs.

Legacy **`userdata1` + 10 GiB fixed + rootfs grow`** layout is retired; do not reintroduce without explicit product decision.
