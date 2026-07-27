## Why

lws-hmi still treats board profile, screen params, and factory identity as App/rootfs concerns while the GPT `oem` partition sits empty. Platformization needs a **ynh960 vertical slice**: OEM owns board×screen SKU + v1 `product.ini` seed; App keeps gpio/modbus; build/flash select variants via `FACTORY_SKU` and ship `oem.img` / `factory.img`.

## What Changes

- Add repo **`oem/`** source tree (packs / boards / screens) and **`make build-oem`** producing ext4 `oem.img`.
- Add early-boot **`oem-compose`**: mount `/oem`, export `/run/hmi/*`, seed `product.ini` into `/var/lib/hal` without clobbering operator keys.
- **BREAKING (runtime profile source):** HMI loads board profile from OEM (or compose export), then merges App gpio/modbus asset paths; App-bundled `board_profile.json` becomes migration fallback only.
- Add `BoardProfile.loadFile` + `withProductConfigs` in `cyber_hal`.
- Thin **`FACTORY_SKU`** resolver: `UBOOT_ID` / `OEM_ID`, bootloader under `prebuilt/bootloader/<uboot_id>/`, factory output `output/firmware/<sku>/factory.img` (transition: `update.img` symlink).
- Pack oem into factory image; `make upgrade` defaults to streaming built `oem.img` when present.
- Docs: Makefile help, README, AGENTS rebuild table; light updates to hal-portability / storage-layout.

**Out of scope:** helpers move into OEM (W2), linux-sdk trim (W3), P3.2 sim+virt / UTM (W4), Factory Test App, full private1 retirement.

## Capabilities

### New Capabilities

- `oem-pack`: OEM pack layout (manifest, board, screen), device paths under `/oem`, compose contract, `build-oem` / SKU selection, factory packing of `oem.img`.

### Modified Capabilities

- `hal-board-profile`: Runtime authority moves to OEM/`/run/hmi`; gpio/modbus remain App-owned; require `loadFile` + product config merge APIs.
- `product-ini`: v1 factory seed lives in OEM board pack; first-boot compose copies into `/var/lib/hal/product.ini` without overwriting non-empty keys.
- `host-remote-upgrade`: Document/require optional default oem stream from `FACTORY_SKU` resolution; contrast with `factory.img` flash.
- `buildroot-lws-hmi-image`: Factory packaging includes oem partition payload; `factory.img` naming with `update.img` compatibility symlink.

## Impact

- **New:** `oem/**`, `board/factory-skus.tsv`, `scripts/factory-sku.sh`, `scripts/build-oem.sh`, overlay `oem-compose.sh` / unit.
- **HAL / App:** `packages/cyber_hal` profile APIs; `app/lws_hmi` startup load path.
- **Build / flash:** `build-img`, `flash`, `upgrade`, package-file, bootloader path layout.
- **Docs / specs:** platform plan already authoritative; this change freezes the W1 slice.
