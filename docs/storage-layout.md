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
| App config / cache | `/userdata/cfg/` (convention) | userdata |

`/userdata` is **not** in `/etc/fstab`. `param-update.service` runs `ynh960-display-init.sh`, which mounts `PARTLABEL=userdata` → `/userdata` and formats on first boot after flash.

## OTA (future)

- **Full `update.img`**: flash replaces **rootfs** partition contents; download staging on **`/userdata/ota/`** (~600 MiB file + margin).
- **A/B system slots**: not in current parameter; would replace fixed 1 GiB rootfs with dual slots in a later parameter revision.

## Changing layout

1. Edit `board/parameter-buildroot-fit.txt`.
2. If rootfs **order** in GPT changes, update `overlay/kernel/rockchip/lws-hmi-ynh960-linux-root.dtsi` (`root=/dev/mmcblk0pN`; currently **p6**).
3. `make apply-overlay` → `make build-kernel` → `make build-img` → **`make flash`** (destructive re-partition).
4. Update this doc and any path references in specs.

Legacy **`userdata1` + 10 GiB fixed + rootfs grow`** layout is retired; do not reintroduce without explicit product decision.
