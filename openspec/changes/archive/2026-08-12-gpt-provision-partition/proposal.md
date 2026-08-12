## Why

Per-unit product identity (`brand` / `model` / `sn`), cloud activation material, and factory tunables (`properties.ini`) must survive **返厂 `make flash`** and **恢复出厂设置** (userdata wipe). OEM seeds and userdata cannot be authorities: shared OEM SN collides in multi-developer QEMU, and userdata is intentionally cleared on flash/reset. Rockchip boards additionally rely on **Vendor Storage** for identity and Loader/Maskrom-visible SN — that contract must stay. We need a second **provision** GPT partition (flash-surviving, never packaged in `factory.img`) for `properties.ini` and, on non-Rockchip SoCs, all provision data.

## What Changes

- Add frozen GPT partition **`provision`** (`PARTLABEL=provision`, ext4, ~4 MiB) before userdata grow; **geometry ABI** after adoption.
- **Rockchip product boards (ynh960 line and future RK boards):** dual persistence — **Vendor Storage** (identity SN/brand/model, cloud Ed25519 sealed ID 22, seal KEK wrap ID 23) **+ provision** (`properties.ini` only). VS remains authoritative for identity on Rockchip; Loader/Maskrom `SN`/`RSN` paths stay valid.
- **Non-Rockchip boards:** **provision only** (identity + `properties.ini` + sealed blobs on the partition).
- **QEMU `sim_virt`:** virtio `provision.img` (per host instance); remove `oem/boards/sim/identity.env`; emulator identity via provision file + optional autogen (not OEM).
- Mount provision early; `/var/lib/hal/properties.ini` binds to provision (not userdata).
- **`package-file` / `factory.img`:** never list `provision` or `vendor*` payloads; extend verify scripts (mirror vendor gate).
- **`make flash`:** compliant factory image defines `provision` in `parameter` but **never writes** `provision.img` → repeat flash preserves provision + VS.
- **Factory-reset / flash userdata policy:** wipe **entire userdata**; **never** format or erase `provision` or Vendor Storage.
- Remove OEM / userdata / `IDENTITY_STUB` as identity authorities.

## Capabilities

### New Capabilities

- `gpt-provision-partition`: GPT layout, mount/bind, flash non-overwrite contract, Rockchip vs non-Rockchip backends, emulator virtio disk, build gates.

### Modified Capabilities

- `vendor-storage-identity`: Rockchip dual-layer with provision; emulator OEM stub removed; flash/reset preserve VS + provision.
- `properties-ini`: `properties.ini` authoritative path on provision partition; not userdata.
- `factory-reset`: full userdata wipe; preserve VS and provision (not selective userdata `hal/` keep).
- `linux-settings-persist`: operator prefs wiped with userdata; `properties.ini` on provision survives.
- `p32-utm-guest`: `provision.img` virtio; drop OEM `identity.env`.
- `oem-pack`: remove sim `identity.env`; no per-unit identity in OEM packs.
- `buildroot-lws-hmi-image`: package-file must omit `provision` payloads (parallel to vendor gate).

## Impact

- **GPT:** `board/parameter-buildroot-fit.txt` (one-time destructive flash for adoption).
- **Overlay:** `display-init` / `bind-prefs`, `read-product-identity.sh` (drop OEM stub), `factory-reset.sh`, provision mount helper.
- **Build:** `package-file`, `verify-no-vendor-payload.sh` → provision, `verify-firmware-partitions.sh`, `build-img.sh`.
- **HAL:** `ProductIniReader` path via provision bind; no identity from userdata ini.
- **Emulator:** `build-emulator.sh`, `run-emulator.sh`, `provision.img`.
- **Docs:** `storage-layout.md`, `hal-portability.md`, `p32-emulator.md`, AGENTS rebuild table.
- **Deletes:** `oem/boards/sim/identity.env`.
