## Why

Daily iteration and field upgrades must not require entering the Rockchip bootloader (`make flash`). Updating **only rootfs** is insufficient: kernel/DTS changes live in **`boot.img`**, and operators need a remote path that is **as close to `make flash` as safely possible** while **preserving userdata / P2.3 prefs**. P2.4 lands **paired A/B slots for boot + rootfs**, **`make upgrade` over SSH**, and machinery **P5.8 OTA** will reuse.

## What Changes

- **BREAKING (GPT):** Split product boot storage into **`boot` / `boot_b`** (vendor U-Boot requires the loaded partition to remain named `boot`) and **`rootfs_a` / `rootfs_b`** in `board/parameter-buildroot-fit.txt`; shift oem/private*/userdata; update `docs/storage-layout.md` and slot-aware boot selection. First adoption needs one **`make flash`** to repartition.
- **Full-system remote upgrade** (default `make upgrade`): transfer a firmware bundle (**at least `boot.img` + `rootfs.img`**, digests; optional `oem` / other non-bootloader images when present) → write **inactive boot + inactive rootfs as one slot pair** → verify → arm try-boot → reboot → confirm or rollback. **Never** format userdata or delete `/userdata/lws-hmi`.
- **Atomic slot pair:** slot A = the A FIT in `boot` + `rootfs_a`; slot B = the B FIT staged through `boot_b` + `rootfs_b`. Try-boot backs up `boot` to `boot_b` and places the target FIT in `boot`, because vendor U-Boot always loads `boot`. Never boot mismatched kernel/rootfs across letters.
- Host: **`make upgrade`** over **USB-SSH / LAN SSH** (same target selection as `push-app`); **no loader / RockUSB**.
- Keep app-only developer iteration in the existing **`make push-app`** workflow; `make upgrade` is full-system A/B only.
- **`make flash` remains** for: GPT/`parameter` change, **U-Boot / MiniLoader**, bricked recovery, and **factory reset** (prefs clear policy).
- **Non-goals:** product Upgrade UI / cloud orchestration (P5.8); Android OTA rewrite; remote rewrite of U-Boot/MiniLoader (too bricky).

## Capabilities

### New Capabilities

- `ab-firmware-slots`: GPT A/B for **boot + rootfs**, paired slot identity, misc try-boot/commit/rollback, and the rule that full-system upgrade updates all safe flashable runtime images in the bundle (boot+rootfs required; oem optional).
- `host-remote-upgrade`: Host `make upgrade` over USB-SSH / registered LAN SSH; transfers full-system firmware bundle (not rootfs-only); invokes board apply; returns when reboot starts/SSH drops without waiting for post-reboot health.

### Modified Capabilities

- `buildroot-lws-hmi-image`: A/B parameter/GPT for boot+rootfs; packaging/`verify-firmware-partitions` for both slot pairs; factory `update.img` populates both letters; overlay ships board upgrade helpers.
- `linux-settings-persist`: Full-system upgrade MUST NOT wipe `/userdata/lws-hmi` (flash = factory reset).

## Impact

- **Partition / boot:** `board/parameter-buildroot-fit.txt`, `docs/storage-layout.md`, kernel/U-Boot slot selection (PARTLABEL / misc), `verify-firmware-partitions.sh`, `build-img` / package-file for dual boot+rootfs in factory image.
- **Rootfs overlay:** board apply/confirm scripts + units; `verify-rootfs-overlay.sh`.
- **Host:** `scripts/upgrade-remote.sh`, Makefile `upgrade` + help/README/AGENTS; must not collide with RockUSB `flash-usb.sh` internal `uf`.
- **Docs / plan:** P2.4 explicitly includes **kernel/boot** in remote upgrade; README dependency row.
- **Downstream:** P5.8 reuses the same bundle + slot protocol.
