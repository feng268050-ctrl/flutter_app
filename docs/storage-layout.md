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
| | oem | ~128 MiB | Board×screen pack |
| | private, private1 | unchanged | Legacy private data (ParamUpdate LCD tables retired) |
| | **vendor0–vendor3** | each **64 KiB** (`0x80`) | Rockchip Vendor Storage (product **brand** / **model** / **sn** + sealed cloud Ed25519 blob ID 22); **geometry frozen ABI** |
| | **provision** | **4 MiB** (`0x2000`) | Factory tunables (`properties.ini`); non-Rockchip identity/sealed blobs; **never in factory.img** |
| | userdata | grow from `0x4C0200` | Operator prefs, models, OTA staging |

**Letter pair:** A = `boot` + `rootfs_a`; B = `boot_b` (storage) + `rootfs_b`. Never mix letters.

**Vendor Storage geometry (frozen after first GPT adoption):**

| PARTNAME | Size | Start LBA |
|----------|------|-----------|
| vendor0 | `0x80` (64 KiB) | `0x4BE000` |
| vendor1 | `0x80` | `0x4BE080` |
| vendor2 | `0x80` | `0x4BE100` |
| vendor3 | `0x80` | `0x4BE180` |
| provision | `0x2000` (4 MiB) | `0x4BE200` |

**provision geometry (frozen after first GPT adoption):** tunables and (on non-Rockchip) identity live here. `package-file` / `factory.img` **must not** embed `provision.img` — same omission contract as vendor. Repeat compliant `make flash` preserves provision bytes when geometry is unchanged.

**Rockchip dual persistence:** Vendor Storage holds identity + cloud sealed ID 22 + seal KEK wrap ID 23; **provision** holds `properties.ini` only. **Non-Rockchip / emulator:** all provision data on the partition (`identity.env`, `properties.ini`, sealed blobs).

ID map: [`board/vendor-storage-ids.txt`](../board/vendor-storage-ids.txt) (SN=1, BRAND=20, MODEL=21, sealed cloud Ed25519 private-key blob=**22** / `VENDOR_CUSTOM_ID_16`); on-device copy at `/usr/libexec/board/vendor-storage-ids.txt`. ID 22 holds **Secrets-sealed ciphertext only** (never plaintext). Helpers: `read-cloud-ed25519-sealed` / `write-cloud-ed25519-sealed`. `package-file` / `factory.img` **must not** embed `vendor*.img` so `make flash` preserves identity (including cloud key). Factory order: **flash → `make write-identity` → verify**. Moving vendor or provision LBAs is a breaking migration (data loss).

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
| Online OTA / host upgrade staged apply | **`/userdata/ota/`** | userdata (not rootfs); cloud + `make upgrade` SSH both stage `tar.gz` here |
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
| Panel timing / MIPI init | Kernel DTB in boot FIT (`overlay/kernel/`) | `boot_*` |
| Screen UI contract (orientation, logical size, ui_scale) | `/oem/screens/<id>/screen.json` → `/run/hmi/screen.env` | oem |
| OEM board×screen pack (SKU authority) | `/oem/` (`manifest.json`, `boards/`, `screens/`, helpers) | oem |
| Compose export (runtime) | `/run/hmi/{oem.env,board_profile.json,screen.env}` | tmpfs |
| **RKNN models** (`*.rknn`, `config.yaml`) | **`/userdata/models/`** | userdata |
| PR0 recording, online OTA staging | `/userdata/…` (incl. **`/userdata/ota/`**) | userdata |
| **Alarm history SQLite** (`alarm_logs` table) | **`/var/lib/hmi/alarm-logs.db`** → `/userdata/hmi/alarm-logs.db` | userdata |
| **Process library SQLite** (`process_presets`, `process_library_meta`) | **`/var/lib/hmi/process-library.db`** → `/userdata/hmi/process-library.db` | userdata |
| **Subsystem state (P2.3+)** | **`/userdata/{wpa_supplicant,network,bluetooth,hmi}/`** (symlinked from `/var/lib/*`) | userdata |
| **Factory tunables** | **`/var/lib/hal/properties.ini`** → **`/mnt/provision/properties.ini`** | **provision** |
| **Non-Rockchip identity** | **`/mnt/provision/identity.env`** | **provision** |
| App config / cache | `/userdata/cfg/` (convention) | userdata |

`/userdata` is **not** in `/etc/fstab`. `storage-init.service` runs `/usr/libexec/board/storage-init.sh` (thin stub that mounts `PARTLABEL=oem` then execs OEM `helpers/storage-init.sh`), which mounts `PARTLABEL=userdata` → `/userdata`, formats on first boot when empty, runs **`provision-mount.sh`** (mount `PARTLABEL=provision` → `/mnt/provision`, bind `properties.ini`), then **`bind-prefs.sh`** to symlink:

- `/var/lib/wpa_supplicant` → `/userdata/wpa_supplicant`
- `/var/lib/network` → `/userdata/network`
- `/var/lib/bluetooth` → `/userdata/bluetooth`
- `/var/lib/hmi` → `/userdata/hmi`
- `/var/lib/hal` → `/userdata/hal` (display/sound/mouse conf — **not** `properties.ini`, which is on provision)

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

Factory **tunables** (`camera_ip`, `control_card_comm_alarm_mode`, …) live at `/var/lib/hal/properties.ini` → `/mnt/provision/properties.ini` (legacy userdata copy migrated once by `provision-mount.sh`). Per-unit **brand** / **model** / **sn** on Rockchip live in **Vendor Storage** (`make write-identity`); on emulator / non-Rockchip in **`/mnt/provision/identity.env`**. Stale identity keys in `properties.ini` are ignored by HAL. OEM packs do **not** seed this file — use `make set-prop` to override. When the file or a key is absent, HAL returns empty and the **LWS HMI App** applies product defaults (`camera_ip=192.168.1.100`, `camera_type=1`, `focus_scale_ref=0`, `control_card_comm_alarm_mode=slide_window`).

## Prefs: flash vs upgrade (P2.3 / P2.4)

Hardware settings are split by subsystem under the userdata trees above (Wi‑Fi under `wpa_supplicant/`, eth0 under `network/`, BT prefs under `bluetooth/`, UI/HW prefs under `hmi/`).

| Operation | What changes | Settings (userdata subsystem trees) |
|-----------|--------------|-------------------------------------|
| **Cold reboot** | nothing on disk | **Keep** — `settings-restore.service` re-applies |
| **`make push-app` / `systemctl restart hmi`** | `/opt/hmi` or HMI process only | **Keep** — stacks are outside `hmi.service` cgroup |
| **`make upgrade` (full-system)** | inactive letter **`boot_*` + `rootfs_*`** (optional oem) | **Keep** — must **not** wipe or rewrite userdata |
| **`make flash`** (RockUSB `update.img`, factory / GPT) | full image path; product **factory reset** | **Must clear userdata** — **provision + VS preserved** |

Notes:

- Rockchip `uf update.img` does **not** rewrite **vendor**, **provision**, or grow **userdata** when omitted from `package-file`. Product policy still requires **userdata wipe** on factory flash (host hygiene or first-boot helper). **provision** and Vendor Storage survive repeat flash when geometry is unchanged.
- **`/usr/bin/factory-reset`** (user 恢复出厂设置) wipes **entire userdata**; never formats provision or VS.
- **`make upgrade`** must never format userdata or delete subsystem userdata trees; that is how OTA keeps operator settings while swapping firmware letters.
- RTC clock time is hardware and is unrelated to this prefs tree.

## OTA / remote upgrade

### `make upgrade` vs `make flash` vs online OTA

| Component | `make upgrade` (SSH) | `make upgrade` (RockUSB Loader/Maskrom) | Online OTA (P4.8) | `make flash` |
|-----------|----------------------|------------------------------------------|-------------------|--------------|
| Kernel FIT | Stage **`tar.gz`** under `/userdata/ota/`, extract, write inactive letter FIT (after `boot`→`boot_b` backup) — **no Ed25519** | **`di`** `boot.img` + `boot_b.img` → `boot` + `boot_b` | Stage **`tar.gz`** + **`.sig`**, **Ed25519 verify**, extract, then `dd` | Yes |
| Rootfs | Same staged extract → inactive `rootfs_*` | **`di`** same `rootfs.img` → **both** `rootfs_a` + `rootfs_b` | Same after verify | Yes |
| oem (optional) | Staged when packaged | **`di`** when packaged | Same when packaged in archive | Yes |
| U-Boot / MiniLoader storage | **No** | **No** (Maskrom may `ul` MiniLoader into **RAM** only) | **No** | Yes |
| GPT / `parameter` | **No** | **No** | **No** | Yes |
| misc | **No** | **No** | **No** | Yes |
| userdata / prefs | **Never wipe** | **Never wipe** | **Never wipe** | **Wipe entire userdata**; **preserve provision + VS** |
| provision / VS | **Never wipe** | **Never wipe** | **Never wipe** | **Never wipe** (omitted from package-file) |
| Full images under `/userdata/ota/` | **Yes** (`tar.gz` only; **no** `.sig` required) | **N/A** (host `di`) | **Yes** (`tar.gz` + `.sig`, then extract) | N/A |
| `factory.img` / `uf` | **No** | **No** | **No** | **Yes** |

- **P4.8 — unified staged OTA**: cloud download and host **`make upgrade`** share `/userdata/ota/` → Ed25519-verify → extract → write inactive letter, all orchestrated by **`packages/cyber_ota`**. Progress is `OtaSession.progress` only (UI + cloud WS); debug appends to `ota.log`. Host SSH path: ephemeral host HTTP serves `tar.gz`+`.sig`; device HMI downloads. Host preflight uses `/usr/libexec/ab/ab-preflight.sh`. Archive from **`make pack-ota`** (or `UPGRADE_PACKAGE=`). **HMI (`/opt/hmi`) updates with rootfs**. Device pubkey `/etc/ota/ed25519.pub`. Retired board scripts: `ab-upgrade-apply.sh`, `ab-upgrade-stream.sh`, `ab-ota-verify.sh`. Boot confirm/rollback remains `ab-boot-confirm.sh`.
- Staging layout:

```text
/userdata/ota/
  ota-package.tar.gz          # required for SSH upgrade + cloud
  ota-package.tar.gz.sig      # required for SSH upgrade + cloud (RockUSB di unsigned)
  ota.log                     # Dart OtaSession append-only debug log
  apply.status                # running|ok|fail (Dart OtaApply)
  # after extract:
  boot.img
  boot_b.img
  rootfs.img
  [oem.img]
  [manifest.json]
```

- **`make push-app`**: developer hot-swap of `/opt/hmi` over SSH — **not** product OTA; remains outside the whole-device gate.
- **Full `update.img` via `make flash`**: factory / first GPT change / U-Boot / intentional **full reset**; not the day-to-day upgrade path.

## Changing layout

1. Edit `board/parameter-buildroot-fit.txt`.
2. Update boot/root selection for letter pairs (`PARTLABEL=rootfs_a|b`; U-Boot loads `boot`, try-boot swaps with `boot_b`); see [`docs/ab-slot-misc.md`](ab-slot-misc.md). Do not leave product boots on a sole pre-A/B `root=/dev/mmcblk0p6` assumption.
3. `make apply-overlay` → `make build-kernel` → `make build-img` → **`make flash`** (destructive re-partition).
4. Update this doc and any path references in specs.

Legacy **`userdata1` + 10 GiB fixed + rootfs grow`** layout is retired; do not reintroduce without explicit product decision.
