# ynh960 bootloader backup — 20260815T130431Z

Rollback snapshot taken before self-built SPL + Linux-first uboot cutover
(`openspec/changes/ynh960-spl-linux-uboot`).

## Prior filenames (authoritative before cutover)

| Role | Path |
|------|------|
| Early loader | `prebuilt/sdk-loader/MiniLoaderAll.bin` (also `prebuilt/bootloader/rockchip-ynh960/MiniLoaderAll.bin` symlink) |
| U-Boot FIT | `prebuilt/sdk-uboot/uboot.img` (also `prebuilt/bootloader/rockchip-ynh960/uboot.img` symlink) |

## Blob identity

| Artifact | Size (bytes) | Markers |
|----------|-------------:|---------|
| MiniLoaderAll.bin | 481728 | `ddr-v1.23-03ea844c5d` (SPL merger; staged historically as `rk356x_spl_loader_v1.23.114.bin`) |
| uboot.img | 4194304 | `bl31-v1.44`, `bl32-v2.15` |

U-Boot bootcmd (vendor): `bootcmd=boot_android ${devtype} ${devnum};boot_fit;bootrkp;run distro_bootcmd;`

Repo git at backup: `b1d2bed9`

## Restore

1. Copy these files back into `prebuilt/bootloader/rockchip-ynh960/` (as `MiniLoaderAll.bin` / `uboot.img`, or reinstall SPL basename + symlink per package README).
2. `FACTORY_SKU=ynh960-p800 make build-img`
3. `make reboot-loader` then `FACTORY_SKU=ynh960-p800 make flash` (or Maskrom `ul` + full flash).

Do not binary-patch restored `uboot.img`.
