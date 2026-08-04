## Why

Per-unit product identity (`brand` / `model` / `sn`) today lives in OEM `product.ini` → compose → `/var/lib/hal/product.ini` (userdata). `make flash` rewrites `oem`, and `oem-compose` force-overwrites those three keys from the OEM seed—so a full factory flash cannot preserve a previously provisioned product SN. Rockchip Vendor Storage (`vendor0`–`vendor3`) is the standard flash-surviving place for factory write-once identity; we need that contract before factory write-number tooling and HAL reads diverge further from the SKU seed model.

## What Changes

- **BREAKING:** `ProductInfo.brand` / `model` / `sn` (and host `read-serial` / `make devices` SN) SHALL come from Rockchip Vendor Storage, not from `product.ini` / OEM seed force-merge.
- Add GPT partitions `vendor0`–`vendor3` (frozen geometry) and ship rootfs tooling to read/write Vendor Storage IDs for brand/model/sn.
- Keep `factory.img` / `package-file` free of vendor payloads so `upgrade_tool uf` (`make flash`) does not overwrite identity; add build-time gates.
- Stop `oem-compose` from force-writing `brand` / `model` / `sn`; OEM `product.ini` remains for tunables only (optional empty-identity fill is out of scope unless tasks add it).
- Add host `make write-identity` (SSH → on-board `vendor_storage`); document optional macOS RockUSB `upgrade_tool SN`/`RSN` for SN-only.
- `product.ini` + `set-prop` / `del-prop` continue for tunables; identity keys stay refused on those commands.

## Capabilities

### New Capabilities

- `vendor-storage-identity`: GPT vendor partitions, flash non-overwrite contract, Vendor Storage ID map for brand/model/sn, board helpers, host write-identity, HAL/read-serial identity source.

### Modified Capabilities

- `product-ini`: Identity properties and host SN resolution move off `product.ini`; OEM compose no longer force-merges brand/model/sn; tunables-only role clarified.
- `oem-pack`: OEM board `product.ini` seed is no longer the authority for per-unit brand/model/sn (tunables seed behavior unchanged unless specified).

## Impact

- GPT: `board/parameter-buildroot-fit.txt` (one-time repartition via `make flash`); docs `storage-layout.md`, AGENTS/README rebuild notes.
- Factory pack: `board/package-file-*`, `scripts/build-img.sh` / verify scripts (reject vendor payloads).
- Rootfs: Rockchip `vendor_storage` / `rktoolkit` (or equivalent), board helpers under `/usr/libexec/hmi/`, `oem-compose.sh`, `read-device-serial.sh`.
- HAL: `packages/cyber_hal` `ProductInfo` identity load path; App unchanged at API surface.
- Host: new write-identity script + Makefile; `set-prop`/`del-prop` keep refusing identity; factory flow = flash then write-identity.
- Emulator / SIM: stub or skip Vendor Storage with documented chip-ID / seed fallback.
