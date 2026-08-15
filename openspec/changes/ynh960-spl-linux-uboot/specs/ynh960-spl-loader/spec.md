## ADDED Requirements

### Requirement: SPL loader delivered as loader.bin

The ynh960 bootloader package under `prebuilt/bootloader/rockchip-ynh960/` SHALL deliver the early Rockchip loader as **`loader.bin`**, produced (or equivalently reproducible) via rkbin **`boot_merger`** with an RK3566 SPL `RKBOOT/*MINIALL*.ini` (FlashBoot = `*_spl_*`, not legacy `*_miniloader_*` for eMMC). Documentation SHALL state that historical `MiniLoaderAll.bin` naming referred to this SPL merger class on ynh960.

#### Scenario: Package contains loader.bin

- **WHEN** an operator lists `prebuilt/bootloader/rockchip-ynh960/` after this change
- **THEN** `loader.bin` is present and is the authoritative early-loader input for factory packaging

#### Scenario: Docs describe SPL not legacy miniloader

- **WHEN** an operator reads `docs/uboot-rkbin.md` (or the package README)
- **THEN** the text SHALL describe ynh960’s early loader as an SPL+DDR merger and SHALL NOT require FlashBoot=`*_miniloader_*` for eMMC

### Requirement: Prior loader backup before replace

Before replacing the shipping early loader for `rockchip-ynh960`, the repository or release process SHALL retain a **backup copy** of the previously validated loader (and SHALL document the backup path and restore steps).

#### Scenario: Backup exists when cutting over

- **WHEN** the new `loader.bin` is installed into `prebuilt/bootloader/rockchip-ynh960/`
- **THEN** a backup of the prior validated loader SHALL exist under a documented rollback path (e.g. `backup/<stamp>/`)
