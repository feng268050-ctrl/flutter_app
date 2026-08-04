## Context

Today per-unit `brand` / `model` / `sn` are seeded from `oem/boards/<id>/product.ini`, force-merged by `oem-compose` into `/var/lib/hal/product.ini` (userdata), and read by HAL / `read-device-serial`. `make flash` packages and rewrites `oem`; compose then overwrites identity again—so factory flash cannot preserve a written product SN. Rockchip Vendor Storage (`/dev/vendor_storage`, GPT `vendor0`–`vendor3`) is the vendor-standard place for flash-surviving factory numbers. This change moves **identity only** there; tunables stay on `product.ini`.

Constraints: ynh960 GPT is product-owned (`board/parameter-buildroot-fit.txt`); `make flash` is macOS `upgrade_tool uf`; rootfs is Buildroot overlay; HAL API surface (`ProductInfo`) should stay stable for the App.

## Goals / Non-Goals

**Goals:**

- Persist BRAND/MODEL/SN across repeated `make flash` when vendor GPT geometry is unchanged and no vendor payload is packaged.
- Single write path for full identity: host SSH → on-board `vendor_storage` (`make write-identity`).
- HAL / `make devices` / `read-serial` SN match Vendor Storage (empty SN → chip ID fallback).
- Build gates so `factory.img` cannot accidentally include vendor images.

**Non-Goals:**

- Writing BRAND/MODEL over RockUSB from macOS `upgrade_tool` (tool exposes `SN`/`RSN` only).
- Moving tunables (`camera_ip`, etc.) off `product.ini`.
- OP-TEE / RPMB / eFuse for identity.
- Auto-provisioning identity inside `make flash` / `factory.img`.
- Guaranteeing userdata wipe on flash (orthogonal prefs policy).

## Decisions

### D1 — Medium: Rockchip Vendor Storage (not `private` / userdata)

- **Choice:** GPT `vendor0`–`vendor3` (64 KiB each, `0x80` sectors), logical store via kernel + `vendor_storage` userspace.
- **Why:** Survives `uf` when omitted from `package-file`; U-Boot/kernel/Linux accessible; aligns with Rockchip write-number practice for SN.
- **Alternatives:** `private` partition file (simpler, non-standard); userdata (flash policy unreliable). Rejected for long-term factory alignment.

### D2 — ID map

| Field | Vendor ID | Notes |
|-------|-----------|--------|
| SN | `VENDOR_SN_ID` (1) | Rockchip standard |
| BRAND | product constant **20** | string |
| MODEL | product constant **21** | string |

- Constants live in one repo source of truth (e.g. `board/vendor-storage-ids.txt` + matching board helper).
- Values: trimmed ASCII, no newlines; SN length capped to Rockchip-typical max (≤30 unless driver proves otherwise).
- **Alternative considered:** single custom blob ID for atomic triple—deferred; three IDs keep `upgrade_tool SN` compatible with SN alone.

### D3 — Flash non-overwrite contract

1. `parameter` **defines** `vendor0`–`vendor3`.
2. `package-file` / `factory.img` **MUST NOT** list or embed `vendor*.img`.
3. Vendor **start/size frozen** after first adoption (geometry ABI); moving LBA requires explicit migration (treat as data loss).
4. `build-img` / verify script fails if package-file matches `vendor[0-3]` or vendor images appear in the factory staging dir.

`upgrade_tool uf` only writes packaged partitions; omitting vendor payloads is the primary hardware guarantee.

### D4 — Write path: SSH + on-board tool (primary)

- `make write-identity BRAND=… MODEL=… SN=…` selects board like other SSH tools; prefer **`CHIPID=`** for selection so `SN=` is not overloaded (document: product assignment uses `SN=` only when not used as device selector—or require `PRODUCT_SN=` / pass SN as dedicated env; **decision:** use `BRAND=` `MODEL=` `PRODUCT_SN=` or `IDENTITY_SN=` for the value, and keep `SN=`/`CHIPID=` for device selection—avoid ambiguity).
- **Clarified:** device selection = existing `SN=`/`CHIPID=`/`IP=`; identity payload = `BRAND=` `MODEL=` `PRODUCT_SN=` (alias `IDENTITY_SN=`).
- On device: refuse overwrite of non-empty SN unless `FORCE=1`.
- Document optional macOS RockUSB: `upgrade_tool SN` / `RSN` for SN-only Loader path; brand/model still need Linux path.

### D5 — Read path / compose

- HAL `ProductInfo.brand|model|sn` ← Vendor Storage; `chipId` unchanged (DT → cpuinfo → fallbacks).
- `read-device-serial` / host enrichment use the same SN rule.
- `oem-compose`: **stop** force-merge of `brand`/`model`/`sn`; seed merge for other keys unchanged (fill-blank). Strip identity keys from OEM seeds in tree (or ignore them if present).
- Runtime `product.ini` MAY still contain stale brand/model/sn lines after migration; HAL MUST ignore them for identity.

### D6 — Rootfs package

- Enable Rockchip `rktoolkit` / `vendor_storage` binary (or vendor equivalent already in SDK Buildroot) on the appliance rootfs; ensure `/dev/vendor_storage` after GPT adoption.
- Thin wrappers under `/usr/libexec/hmi/` for read/write identity (verb-noun), exposed as needed for host scripts.

### D7 — Emulator / SIM

- QEMU without Vendor Storage: HAL falls back to chip ID / documented stub; `write-identity` may no-op or fail clearly. SIM seed `sn=` in OEM is not the production authority.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| First flash with new GPT creates empty vendor → identity gone until rewrite | Document factory order: flash (new GPT) → write-identity; one-time per board after adoption |
| Later parameter edit moves vendor LBAs | Freeze geometry in docs + verify; CI diff alert on vendor offsets |
| Someone adds vendor to package-file | Hard fail in build-img / verify |
| `oem-compose` or leftover ini still “looks like” identity | HAL ignores ini for brand/model/sn; strip seeds |
| macOS-only RockUSB SN ≠ full identity | Primary path is SSH write-identity; document SN-only RockUSB |
| Custom IDs 20/21 collide with future Rockchip IDs | Document reserved range; adjust before field freeze if SDK conflicts |

## Migration Plan

1. Land GPT + package gates + `vendor_storage` in rootfs (boards need one `make flash` to adopt GPT).
2. Land board helpers + HAL/read-serial + write-identity; dual-read optional only during bring-up if needed (prefer hard cut: Vendor Storage only).
3. Remove compose force-identity; clean OEM seeds.
4. Factory SOP: flash → write-identity → verify `make devices` SN / RSN.
5. Rollback: re-enable ini identity only via revert of this change (no automatic dual-write).

## Open Questions

- Exact `parameter` LBA insertion point (before userdata vs Rockchip early fixed region)—resolve against Innohi MiniLoader layout during implement; prefer insert before userdata without moving uboot/boot.
- Whether Buildroot symbol is `BR2_PACKAGE_RKTOOLKIT` vs dangling `VENDOR_STORAGE`—confirm against SDK package that actually installs `/usr/bin/vendor_storage`.
- Optional: sync written SN into RockUSB-visible SN so Loader `RSN` matches product SN without separate `upgrade_tool SN` (likely automatic if both use `VENDOR_SN_ID`).
