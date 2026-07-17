# eMMC storage layout (ynh960 product line)

Single GPT for all ynh960/961/962 SKUs. Defined in [`board/parameter-buildroot-fit.txt`](../board/parameter-buildroot-fit.txt); applied on **`make flash`** (full re-partition).

**A/B misc marker:** [`docs/ab-slot-misc.md`](ab-slot-misc.md).

## Partition table

Rockchip `parameter.txt` uses **512-byte sectors**.

### Current (P2.4 — paired A/B)

| Order | PARTNAME | Size | Role |
|-------|----------|------|------|
| boot chain | uboot, misc | unchanged | **U-Boot content: `make flash` only**; misc holds slot letter ([ab-slot-misc](ab-slot-misc.md)) |
| | **boot**, **boot_b** | each ~64 MiB (`0x00020000`) | Kernel FIT; U-Boot loads **`boot`**; apply backs up to `boot_b` then writes try FIT to `boot` |
| | recovery, backup | keep single (current sizes) | Not A/B in P2.4 |
| system | **rootfs_a**, **rootfs_b** | each **1 GiB** | Userspace; remote upgrade writes inactive letter |

**Letter pair:** A = `boot` + `rootfs_a`; B = `boot_b` (storage) + `rootfs_b`. Never mix letters.

Mount: kernel uses `root=PARTLABEL=rootfs_a` or `rootfs_b`. Prefer PARTLABEL over raw `/dev/mmcblk0pN`.

**Why not `boot_a`?** Vendor U-Boot logs `FIT: No boot partition` / `Can't find part: boot` unless a partition is named exactly `boot`. See [`ab-slot-misc.md`](ab-slot-misc.md).

### Why rootfs is 1 GiB (not 3 GiB)

| Content | Where | Size (product budget) |
|---------|--------|------------------------|
| Buildroot system + libs (P5) | `/` rootfs | **≤ ~500 MiB** in flash image |
| Flutter `/opt/hmi` | `/` rootfs | **≤ ~800 MiB** worst case via `push-app` (typical P5 UI **30–70 MiB**) |
| RKNN models | **`/userdata/models/`** | userdata (not rootfs) |
| OTA download / upgrade staging | **`/userdata/ota/`** | userdata (not rootfs) |
| PR0 录像 / sqlite | `/userdata/…` | userdata |

**`update.img` whole package ≤ ~600 MiB** (boot + rootfs + misc…) ⇒ **`rootfs.ext2` ~430–550 MiB** today/P5 target.  
**1 GiB partition** ≈ 2× that budget — enough for ext4 metadata and a few `push-app` iterations without repartitioning.

### ext4 image size (Buildroot / OTA)

Rockchip `base.config` sets `BR2_TARGET_ROOTFS_EXT2_SIZE_AUTO=y`. Buildroot then:

1. **`mkfs.ext4`** at `(du(target) + find|wc × blksz) × **110%** + **64 MiB**`
2. **`resize2fs -M`** — shrink to minimum blocks

The **110% / 64 MiB margin does not appear in the final `rootfs.img`** when shrink succeeds. What inflated past images (~502 MiB vs ~388 MiB payload) was mainly **`BR2_TARGET_ROOTFS_EXT2_INODES=0`** (auto ≈ one inode per 4 KiB → ~128k inodes / ~124k unused) plus **`resize2fs -M` hitting that inode-table floor**.

lws-hmi overrides in `overlay/buildroot/chips/lws_hmi_rootfs.config`:

| Option | Value | Effect |
|--------|-------|--------|
| `BR2_TARGET_ROOTFS_EXT2_SIZE_AUTO` | `n` | Fixed cap instead of auto formula |
| `BR2_TARGET_ROOTFS_EXT2_SIZE` | `450M` | OTA artifact ~450 MiB; ~30 MiB free blocks inside FS for `push-app` |
| `BR2_TARGET_ROOTFS_EXT2_INODES` | `10240` | ~5.7k free inodes; avoids inode-table bloat |
| `BR2_TARGET_ROOTFS_EXT2_RESBLKS` | `0` | No 5% root-reserved pool (embedded appliance) |

To change OTA size later: bump `450M` (still must pass `verify-firmware-partitions.sh` vs 1 GiB slot). Pure `SIZE_AUTO` + low `-N` shrinks the image further (~417 MiB) but leaves almost no grow room on `/` until repartition or a deliberate grow step — not used here.

If uncompressed rootfs on device ever approaches **~900 MiB**, bump `0x00200000` → `0x00300000` (1.5 GiB) in parameter and re-flash.

### Typical capacities

| eMMC (nominal) | ~usable | rootfs A+B | userdata (approx.) |
|----------------|---------|------------|---------------------|
| 32 GiB | ~29 GiB | **2×1 GiB** (+ dual boot ~+64 MiB vs single-boot) | **~26 GiB** |
| 16 GiB | ~15 GiB | same | **~12 GiB** |

`scripts/verify-firmware-partitions.sh` fails the build if `boot.img` / `rootfs.img` exceed either letter’s GPT slot.

## Runtime paths

| Content | Path | Partition |
|---------|------|-----------|
| Buildroot rootfs, `/opt/hmi`, libs | `/` | active `rootfs_*` |
| Kernel FIT | — | active `boot_*` |
| LCD/MIPI params (seed) | `/mnt/private1/` | private1 |
| OEM / vendor drop-ins (optional) | `/oem/` | oem |
| **RKNN models** (`*.rknn`, `config.yaml`) | **`/userdata/models/`** | userdata |
| PR0 recording, sqlite, OTA download / upgrade staging | `/userdata/…` (incl. **`/userdata/ota/`**) | userdata |
| **Subsystem state (P2.3+)** | **`/userdata/{wpa_supplicant,network,bluetooth,hmi}/`** (symlinked from `/var/lib/*`) | userdata |
| App config / cache | `/userdata/cfg/` (convention) | userdata |

`/userdata` is **not** in `/etc/fstab`. `param-update.service` runs `ynh960-display-init.sh`, which mounts `PARTLABEL=userdata` → `/userdata`, formats on first boot when empty, then runs **`bind-prefs.sh`** to symlink:

- `/var/lib/wpa_supplicant` → `/userdata/wpa_supplicant`
- `/var/lib/network` → `/userdata/network`
- `/var/lib/bluetooth` → `/userdata/bluetooth`
- `/var/lib/hmi` → `/userdata/hmi`

## Prefs: flash vs upgrade (P2.3 / P2.4)

Hardware settings are split by subsystem under the userdata trees above (Wi‑Fi under `wpa_supplicant/`, eth0 under `network/`, BT prefs under `bluetooth/`, UI/HW prefs under `hmi/`).

| Operation | What changes | Settings (userdata subsystem trees) |
|-----------|--------------|-------------------------------------|
| **Cold reboot** | nothing on disk | **Keep** — `settings-restore.service` re-applies |
| **`make push-app` / `systemctl restart hmi`** | `/opt/hmi` or HMI process only | **Keep** — stacks are outside `hmi.service` cgroup |
| **`make upgrade` (full-system)** | inactive letter **`boot_*` + `rootfs_*`** (optional oem) | **Keep** — must **not** wipe or rewrite userdata |
| **`make flash`** (RockUSB `update.img`, factory / GPT) | full image path; product **factory reset** | **Must clear** — complete reset after flash |

Notes:

- Rockchip `uf update.img` often **does not** rewrite the grow **userdata** partition by itself. Product policy still requires a **flash-time wipe of prefs** on factory flash. Until that lands, do not assume bare `make flash` already erased Wi‑Fi credentials.
- **`make upgrade`** must never format userdata or delete subsystem userdata trees; that is how OTA keeps operator settings while swapping firmware letters.
- RTC clock time is hardware and is unrelated to this prefs tree.

## OTA / remote upgrade

### `make upgrade` vs `make flash`

| Component | `make upgrade` (full-system) | `make flash` |
|-----------|------------------------------|--------------|
| Kernel FIT (`boot.img`) | **Yes** → inactive `boot_*` | Yes |
| Rootfs (`rootfs.img`) | **Yes** → inactive `rootfs_*` | Yes |
| oem (if in bundle) | **Yes** (single partition) | Yes |
| U-Boot / MiniLoader | **No** | Yes |
| GPT / `parameter` | **No** | Yes |
| userdata / prefs | **Never wipe** | Factory reset |

- **P2.4 — paired A/B boot+rootfs**: inactive-letter write + try-boot + reboot (**no bootloader flash**). Host: **`make upgrade`** over USB-SSH or LAN SSH. Bundle ≥ **`boot.img` + `rootfs.img`**. **userdata preserved.**
- **P5.8 — product OTA**: UI / cloud (or local) orchestration on top of the P2.4 full-system A/B protocol. Developer app-only iteration remains `make push-app`; staging is under **`/userdata/ota/`**.
- **Full `update.img` via `make flash`**: factory / first GPT change / U-Boot / intentional **full reset**; not the day-to-day upgrade path after P2.4.

## Changing layout

1. Edit `board/parameter-buildroot-fit.txt`.
2. Update boot/root selection for letter pairs (`PARTLABEL=rootfs_a|b`; U-Boot loads `boot`, try-boot swaps with `boot_b`); see [`docs/ab-slot-misc.md`](ab-slot-misc.md). Do not leave product boots on a sole pre-A/B `root=/dev/mmcblk0p6` assumption.
3. `make apply-overlay` → `make build-kernel` → `make build-img` → **`make flash`** (destructive re-partition).
4. Update this doc and any path references in specs.

Legacy **`userdata1` + 10 GiB fixed + rootfs grow`** layout is retired; do not reintroduce without explicit product decision.
