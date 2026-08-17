# ynh960-spl-loader

## Requirements

### Requirement: SPL loader delivered as rkbin OUTPUT basename

The ynh960 bootloader package under `prebuilt/bootloader/rockchip-ynh960/` SHALL deliver the early Rockchip loader as the **rkbin `boot_merger` OUTPUT** filename matching **`rk356x_spl_loader_v*.bin`**, produced (or equivalently reproducible) via rkbin **`boot_merger`** with an RK3566 SPL `RKBOOT/*MINIALL*.ini` (FlashBoot = `*_spl_*`, not legacy `*_miniloader_*` for eMMC). The package README SHALL pin the exact OUTPUT basename, ini, and tool/git identity. The repository MUST NOT treat invented names such as `loader.bin` or `bootloader.bin` as the authoritative early-loader artifact. Documentation SHALL state that historical `MiniLoaderAll.bin` naming referred to this SPL merger class on ynh960 and MAY remain only as a transitional symlink to the `rk356x_spl_loader_v*.bin` file.

#### Scenario: Package contains rk356x_spl_loader

- **WHEN** an operator lists `prebuilt/bootloader/rockchip-ynh960/` after this change
- **THEN** exactly one `rk356x_spl_loader_v*.bin` (or the README-pinned basename) is present and is the authoritative early-loader input for factory packaging

#### Scenario: Docs describe SPL not legacy miniloader

- **WHEN** an operator reads `docs/uboot-rkbin.md` (or the package README)
- **THEN** the text SHALL describe ynh960’s early loader as an SPL+DDR merger named per rkbin OUTPUT and SHALL NOT require FlashBoot=`*_miniloader_*` for eMMC

### Requirement: Prior loader backup before replace

Before replacing the shipping early loader for `rockchip-ynh960`, the repository or release process SHALL retain a **backup copy** of the previously validated loader (and SHALL document the backup path and restore steps).

#### Scenario: Backup exists when cutting over

- **WHEN** the new `rk356x_spl_loader_v*.bin` is installed into `prebuilt/bootloader/rockchip-ynh960/`
- **THEN** a backup of the prior validated loader SHALL exist under a documented rollback path (e.g. `backup/<stamp>/`)
