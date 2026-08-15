## 1. Backup and naming

- [ ] 1.1 Create dated backup of current `prebuilt/sdk-loader/MiniLoaderAll.bin` and `prebuilt/sdk-uboot/uboot.img` (resolve symlinks) under `prebuilt/bootloader/rockchip-ynh960/backup/<stamp>/` with README (sizes, `ddr-v*`, `bl31-v*`, `bl32-v*`, prior filenames)
- [ ] 1.2 Define install layout: `rk356x_spl_loader_v*.bin` (rkbin OUTPUT as-is) + `uboot.img` under `prebuilt/bootloader/rockchip-ynh960/`; document optional `MiniLoaderAll.bin` → that SPL file symlink for tool compat; do **not** ship authoritative `loader.bin` / `bootloader.bin`

## 2. Self-build SPL loader

- [ ] 2.1 Fetch/pin rkbin revision; select `RK3566MINIALL*.ini` matching ynh960 DRAM (start from current `ddr-v1.23` lineage evidence)
- [ ] 2.2 Run `boot_merger`; install OUTPUT **`rk356x_spl_loader_v*.bin`** unchanged; record ini + exact OUTPUT basename in package README
- [ ] 2.3 Update `scripts/build-img.sh` (and flash/Maskrom helpers) to resolve `rk356x_spl_loader_*.bin` (exactly one match or README pin), keep transitional `MiniLoaderAll.bin` fallback/symlink

## 3. Self-build Linux-first U-Boot

- [ ] 3.1 `make fetch-uboot` (or documented clone); verify/extend `patch-uboot-bootcmd.sh` so no `boot_android` before `boot_fit`; add overlay patch if upstream block shape changed
- [ ] 3.2 Pack `uboot.img` using SDK `RK3568TRUST.ini` pins **BL31 v1.44 / BL32 v2.15** (do not use master v1.46/v2.16)
- [ ] 3.3 Install to `prebuilt/bootloader/rockchip-ynh960/uboot.img`; verify strings `bl31-v1.44` and `bl32-v2.15`
- [ ] 3.4 Update docs (`docs/uboot-rkbin.md`, make-commands, package README); remove stale “never build uboot” / MiniLoader-as-architecture wording; document rkbin OUTPUT naming

## 4. Factory package and lab validation

- [ ] 4.1 `FACTORY_SKU=ynh960-p800 make build-img` with new pair; confirm factory packages the `rk356x_spl_loader_*.bin` blob
- [ ] 4.2 Flash lab ynh960; serial confirm Linux-first boot (no Android FIT attempt); HMI smoke; `/dev/tee0` + seal smoke
- [ ] 4.3 Document rollback: restore backup → rebuild factory → flash; practice once if time permits
- [ ] 4.4 Mark change ready to unblock `ek3562-board-bringup` bootloader flash gate
