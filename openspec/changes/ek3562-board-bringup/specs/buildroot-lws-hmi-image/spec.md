## MODIFIED Requirements

### Requirement: Factory artifact named factory.img includes oem

`make build-img` SHALL produce `output/firmware/<APP>/<factory_sku>/factory.img` for the resolved `APP` (default `lws_hmi`) and `FACTORY_SKU`, packaging **early loader** (`loader.bin`, with documented transitional `MiniLoaderAll.bin` fallback/symlink if required) and uboot from `prebuilt/bootloader/<uboot_id>/`, misc, dual FIT, rootfs from `output/firmware/<APP>/rootfs.img`, and **oem** when `oem.img` is present for the resolved `OEM_ID`. This SHALL apply to `FACTORY_SKU=ek3562-dev` (`uboot_id` `vendor-ek3562`) as well as ynh960 SKUs. A sibling `manifest.txt` SHALL record `app`, `uboot_id`, `oem_id`, and git/build identity. During migration, `output/firmware/update.img` SHALL remain usable as a symlink or copy of the selected/default APP + sku's `factory.img`.

#### Scenario: build-img writes per-APP per-sku factory.img

- **WHEN** `APP=lws_hmi` and `FACTORY_SKU=ynh960-p800` and `make build-img` succeeds
- **THEN** `output/firmware/lws_hmi/ynh960-p800/factory.img` and `manifest.txt` exist

#### Scenario: ek3562-dev factory.img

- **WHEN** `FACTORY_SKU=ek3562-dev` and bootloader inputs exist under `prebuilt/bootloader/vendor-ek3562/` and `make build-img` succeeds
- **THEN** `output/firmware/<APP>/ek3562-dev/factory.img` exists and packages that SKU’s loader and uboot
