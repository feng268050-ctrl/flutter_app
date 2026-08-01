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
| Flutter `/opt/hmi` | `/` rootfs | App AOT + assets；**may include product binaries** (MediaMTX, `lws_ai_daemon` + libs) via `push-app` |
| RKNN models | **`/userdata/models/`** | userdata (not rootfs) |
| AI daemon workdir | **`/var/lib/hmi/ai/`** | durable App state |
| AI control sockets | **`/run/hmi/ai/`** | tmpfs (`cmd.sock` / `evt.sock`) |
| Online OTA download / staged apply | **`/userdata/ota/`** | userdata (not rootfs); not used for full images by `make upgrade` |
| PR0 录像 / sqlite | `/userdata/…` | userdata |

**`update.img` whole package** grows with rootfs; keep `rootfs.ext2` at **`600M`** (both stacks) so the 1 GiB GPT slot still has room for metadata and a few `push-app` iterations.

### ext4 image size (Buildroot / OTA)

Rockchip `base.config` sets `BR2_TARGET_ROOTFS_EXT2_SIZE_AUTO=y`. Buildroot then:

1. **`mkfs.ext4`** at `(du(target) + find|wc × blksz) × **110%** + **64 MiB**`
2. **`resize2fs -M`** — shrink to minimum blocks

The **110% / 64 MiB margin does not appear in the final `rootfs.img`** when shrink succeeds. What inflated past images (~502 MiB vs ~388 MiB payload) was mainly **`BR2_TARGET_ROOTFS_EXT2_INODES=0`** (auto ≈ one inode per 4 KiB → ~128k inodes / ~124k unused) plus **`resize2fs -M` hitting that inode-table floor**.

lws-hmi overrides in `overlay/buildroot/chips/lws_hmi_rootfs.config`:

| Option | Value | Effect |
|--------|-------|--------|
| `BR2_TARGET_ROOTFS_EXT2_SIZE_AUTO` | `n` | Fixed cap instead of auto formula |
| `BR2_TARGET_ROOTFS_EXT2_SIZE` | `600M` | Weston/eLinux image; headroom for GStreamer/CJK fonts + `push-app` |
| `BR2_TARGET_ROOTFS_EXT2_INODES` | `10240` | ~5.7k free inodes; avoids inode-table bloat |
| `BR2_TARGET_ROOTFS_EXT2_RESBLKS` | `0` | No 5% root-reserved pool (embedded appliance) |

To change OTA size later: bump `600M` (still must pass `verify-firmware-partitions.sh` vs 1 GiB slot). Pure `SIZE_AUTO` + low `-N` shrinks the image further but leaves almost no grow room on `/` until repartition or a deliberate grow step — not used here.

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
| LCD/MIPI params (runtime seed) | `/mnt/private1/` (seeded at boot from OEM only) | private1 |
| LCD/MIPI param **authority** | `/oem/screens/<id>/lcd/` (required; no `/system/etc` seed fallback) | oem |
| OEM board×screen pack (SKU authority) | `/oem/` (`manifest.json`, `boards/`, `screens/`, helpers) | oem |
| Compose export (runtime) | `/run/hmi/{oem.env,board_profile.json,screen.env}` | tmpfs |
| **RKNN models** (`*.rknn`, `config.yaml`) | **`/userdata/models/`** | userdata |
| PR0 recording, online OTA staging | `/userdata/…` (incl. **`/userdata/ota/`**) | userdata |
| **Alarm history SQLite** (`alarm_logs` table) | **`/var/lib/hmi/alarm-logs.db`** → `/userdata/hmi/alarm-logs.db` | userdata |
| **Process library SQLite** (`process_presets`, `process_library_meta`) | **`/var/lib/hmi/process-library.db`** → `/userdata/hmi/process-library.db` | userdata |
| **Subsystem state (P2.3+)** | **`/userdata/{wpa_supplicant,network,bluetooth,hmi}/`** (symlinked from `/var/lib/*`) | userdata |
| App config / cache | `/userdata/cfg/` (convention) | userdata |

`/userdata` is **not** in `/etc/fstab`. `param-update.service` runs `/usr/libexec/hmi/ynh960-display-init.sh` (thin stub that mounts `PARTLABEL=oem` then execs OEM `helpers/display-init.sh`), which mounts `PARTLABEL=userdata` → `/userdata`, formats on first boot when empty, then runs **`bind-prefs.sh`** to symlink:

- `/var/lib/wpa_supplicant` → `/userdata/wpa_supplicant`
- `/var/lib/network` → `/userdata/network`
- `/var/lib/bluetooth` → `/userdata/bluetooth`
- `/var/lib/hmi` → `/userdata/hmi`

Notable files under `/var/lib/wpa_supplicant` (Wi‑Fi; persist across `make upgrade` / `push-app`):

| File | Role |
|------|------|
| `wpa_supplicant.conf` | Non-secret network metadata (SSID, `key_mgmt`, Auto Join / `disabled`, `scan_ssid`, …). **Must not** contain plaintext `psk=` / passphrase after vault migration. Seed template is PSK-free. |
| `credentials.vault` | Encrypted Wi‑Fi PSK vault (HAL Secrets seal; AAD purpose `wifi-psk`). See [`docs/wifi-credential-vault.md`](wifi-credential-vault.md). |
| `wifi-wanted` | Radio-wanted marker for HAL restore |
| `wlan0-ipv4` (etc.) | Per-iface IPv4 prefs |
| `wpa_supplicant.log` | wpa runtime log |

Notable files under `/var/lib/hmi` (persist across `make upgrade` / `push-app`):

| File | Role |
|------|------|
| `alarm-logs.db` | SQLite alarm history; single table `alarm_logs` (`timestamp` epoch ms; display `YYYY-MM-DD HH:mm`) |
| `process-library.db` | Versioned built-in and user process presets; WAL-enabled SQLite |
| `misc-settings.json`, `mouse.conf`, … | Other HMI prefs |

Factory identity and tunables (`brand`, `model`, `sn`, `camera_ip`, `control_card_comm_alarm_mode`, …) are stored separately at `/var/lib/hal/product.ini` → `/userdata/hal/product.ini`.

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

### `make upgrade` vs `make flash` vs online OTA

| Component | `make upgrade` (dev SSH) | Online OTA (P4.8) | `make flash` |
|-----------|--------------------------|-------------------|--------------|
| Kernel FIT | **Stream** inactive letter’s FIT → `boot` (after `boot`→`boot_b` backup) | Stage under `/userdata/ota/` + `*.sig`, **Ed25519 verify**, then `dd` | Yes |
| Rootfs | **Stream** → inactive `rootfs_*` | Stage + `*.sig`, Ed25519 verify, then `dd` | Yes |
| oem (optional) | **Stream** when packaged | Stage + `*.sig` when packaged | Yes |
| U-Boot / MiniLoader | **No** | **No** | Yes |
| GPT / `parameter` | **No** | **No** | Yes |
| userdata / prefs | **Never wipe** | **Never wipe** | Factory reset |
| Full images under `/userdata/ota/` | **No** (helpers/status only) | **Yes** (download then signed apply) | N/A |

- **P2.5 — paired A/B boot+rootfs**: **`make upgrade`** = **stream-to-partition** over USB-SSH or LAN SSH (one operator wait aligned with write progress). Host needs both FITs built locally; only the inactive letter’s FIT is transferred. **userdata preserved.** Dev-only; not product OTA and not a substitute for signature gates.
- **P4.8 — product OTA (single-level full firmware)**: download (or local package) → **`/userdata/ota/`** → **Ed25519-verify each complete image** (detached `*.img.sig`; hash-then-sign over the whole file) → **`ab-upgrade-apply.sh`** writes only the **inactive** letter; **userdata not wiped**. Payload = `boot.img` + `boot_b.img` + `rootfs.img` (optional `oem.img`); **HMI (`/opt/hmi`) updates with rootfs** — no product App-only / two-level OTA. **No separate `.sha256` / digest gate** on the product path (verify already authenticates integrity). `manifest.json` (if kept) is UX metadata only, **not** a trust root. Refuse apply until pubkey verify succeeds. Device pubkey e.g. `/etc/hmi/ota-ed25519.pub`; private key only on publish host/HSM.
- Staging layout (product OTA):

```text
/userdata/ota/
  boot.img
  boot.img.sig
  boot_b.img
  boot_b.img.sig
  rootfs.img
  rootfs.img.sig
  [oem.img / oem.img.sig]
```

- **`make push-app`**: developer hot-swap of `/opt/hmi` over SSH — **not** product OTA.
- **Full `update.img` via `make flash`**: factory / first GPT change / U-Boot / intentional **full reset**; not the day-to-day upgrade path after P2.5.

## Changing layout

1. Edit `board/parameter-buildroot-fit.txt`.
2. Update boot/root selection for letter pairs (`PARTLABEL=rootfs_a|b`; U-Boot loads `boot`, try-boot swaps with `boot_b`); see [`docs/ab-slot-misc.md`](ab-slot-misc.md). Do not leave product boots on a sole pre-A/B `root=/dev/mmcblk0p6` assumption.
3. `make apply-overlay` → `make build-kernel` → `make build-img` → **`make flash`** (destructive re-partition).
4. Update this doc and any path references in specs.

Legacy **`userdata1` + 10 GiB fixed + rootfs grow`** layout is retired; do not reintroduce without explicit product decision.
