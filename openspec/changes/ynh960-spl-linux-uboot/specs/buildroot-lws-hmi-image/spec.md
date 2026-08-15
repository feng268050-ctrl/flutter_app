## MODIFIED Requirements

### Requirement: Factory artifact named factory.img includes oem

`make build-img` SHALL produce `output/firmware/<APP>/<factory_sku>/factory.img` for the resolved `APP` (default `lws_hmi`) and `FACTORY_SKU`, packaging **early loader** and uboot from `prebuilt/bootloader/<uboot_id>/`, misc, dual FIT, rootfs from `output/firmware/<APP>/rootfs.img`, and **oem** when `oem.img` is present for the resolved `OEM_ID`. For RK3566/ynh960-class packages the early loader file SHALL be the rkbin OUTPUT basename **`rk356x_spl_loader_v*.bin`** when present (scripts resolve the glob or README-pinned name; exactly one match required). Implementations MAY accept a transitional `MiniLoaderAll.bin` only as a documented fallback or symlink to that `rk356x_spl_loader_v*.bin`. Invented names such as `loader.bin` or `bootloader.bin` MUST NOT be required as the authoritative input. A sibling `manifest.txt` SHALL record `app`, `uboot_id`, `oem_id`, and git/build identity. During migration, `output/firmware/update.img` SHALL remain usable as a symlink or copy of the selected/default APP + sku's `factory.img` so existing flash defaults keep working.

#### Scenario: build-img writes per-APP per-sku factory.img

- **WHEN** `APP=lws_hmi` and `FACTORY_SKU=ynh960-p800` and `make build-img` succeeds
- **THEN** `output/firmware/lws_hmi/ynh960-p800/factory.img` and `manifest.txt` exist

#### Scenario: flash uses FACTORY_SKU and APP

- **WHEN** the operator sets `FACTORY_SKU=ynh960-p800` and `APP=lws_hmi` (or defaults) for `make flash`
- **THEN** the flash path SHALL target that APP+sku's `factory.img` (or the compatible `update.img` symlink to it)

#### Scenario: Packaging prefers rk356x_spl_loader

- **WHEN** `prebuilt/bootloader/<uboot_id>/rk356x_spl_loader_v*.bin` exists for the resolved SKU (exactly one match or README pin)
- **THEN** `make build-img` SHALL use that file as the early loader input (MUST NOT require `MiniLoaderAll.bin` as the only accepted authoritative name)
