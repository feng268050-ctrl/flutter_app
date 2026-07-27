## 1. OEM source tree

- [x] 1.1 Create `oem/packs/ynh960+panel-800x1280/manifest.json`, `oem/boards/ynh960/board_profile.json` (no gpio/modbus), `oem/boards/ynh960/product.ini`, `oem/screens/panel-ynh960-800x1280/screen.json`
- [x] 1.2 Add `board/factory-skus.tsv` and `prebuilt/bootloader/rockchip-ynh960/` (from existing sdk-uboot/sdk-loader)
- [x] 1.3 Gitignore `oem/out/`; keep App `assets/hal/board_profile.json` as migration fallback only

## 2. HAL + App load path

- [x] 2.1 Add `BoardProfile.loadFile` and `withProductConfigs` in `cyber_hal`
- [x] 2.2 Add unit tests for OEM fixture + App gpio/modbus merge
- [x] 2.3 Update `app/lws_hmi` main to prefer `/run/hmi/board_profile.json` then OEM path, merge App configs, asset fallback with warning

## 3. oem-compose

- [x] 3.1 Add `oem-compose.sh` + `oem-compose.service` (Before hmi); mount `/oem`; write `/run/hmi/*`; merge product.ini seed
- [x] 3.2 Bundle rootfs migration fallback under `/usr/share/hmi/oem-fallback/`; wire verify-rootfs-overlay checks
- [x] 3.3 Update light docs: `hal-portability.md`, `storage-layout.md` pointers

## 4. build-oem / factory / upgrade

- [x] 4.1 Add `scripts/factory-sku.sh` and `scripts/build-oem.sh`; Makefile `build-oem`
- [x] 4.2 Update `build-img` / package-file / flash defaults for per-sku `factory.img` + oem + `update.img` symlink
- [x] 4.3 Update `upgrade-remote.sh` to default `UPGRADE_OEM_IMG` from resolver; sync Makefile help, README, AGENTS rebuild table
