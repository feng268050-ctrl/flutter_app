# rockchip-ynh960 bootloader package

Self-built Rockchip early loader + U-Boot for ynh960 (RK3566 eMMC).  
OpenSpec: `openspec/changes/ynh960-spl-linux-uboot`.

## Authoritative artifacts

| Role | Filename | Notes |
|------|----------|--------|
| Early loader (SPL+DDR) | **`rk356x_spl_loader_v1.23.114.bin`** | Exact rkbin `boot_merger` `[OUTPUT] PATH=` — **do not** invent `loader.bin` / `bootloader.bin` |
| U-Boot FIT | **`uboot.img`** | Linux-first `RKIMG_BOOTCOMMAND`; TRUST **BL31 v1.44 / BL32 v2.15** |
| Tool compat (optional) | `MiniLoaderAll.bin` | Symlink → the `rk356x_spl_loader_*.bin` above (`package-file` / some `upgrade_tool` paths still use this basename) |

`make build-img` / `FACTORY_SKU` resolution reads this directory (`UBOOT_ID=rockchip-ynh960`).  
Scripts require **exactly one** `rk356x_spl_loader_*.bin` (or set `FACTORY_SPL_LOADER=` to the basename).

## SPL build pin

| Field | Value |
|-------|--------|
| Ini | `RKBOOT/RK3566MINIALL.ini` (DDR 1056 MHz v1.23 lineage) |
| FlashData | `bin/rk35/rk3566_ddr_1056MHz_v1.23.bin` |
| FlashBoot | `bin/rk35/rk356x_spl_v1.14.bin` (`*_spl_*`, not legacy miniloader) |
| OUTPUT | `rk356x_spl_loader_v1.23.114.bin` |
| DDR string | `ddr-v1.23-03ea844c5d` |
| rkbin tree | SDK `linux-sdk/rkbin` (same bins as lunch; not github master DDR v1.25) |
| Tool | `./tools/boot_merger` (rkbin) |

Rebuild:

```bash
cd linux-sdk/rkbin   # or Docker /work/sdk/rkbin
./tools/boot_merger RKBOOT/RK3566MINIALL.ini
cp -f rk356x_spl_loader_v1.23.114.bin \
  ../../prebuilt/bootloader/rockchip-ynh960/
```

## U-Boot build pin

| Field | Value |
|-------|--------|
| Source | `make fetch-uboot` → `linux-sdk/u-boot` (`overlay/third-party/uboot.version`) |
| Bootcmd | `patch-uboot-bootcmd.sh`: `run rkimg_bootdev; boot_fit; run distro_bootcmd;` (no `boot_android` before `boot_fit`) |
| TRUST | SDK `RKTRUST/RK3568TRUST.ini` → `rk3568_bl31_v1.44.elf` + `rk3568_bl32_v2.15.bin` |
| Verify | `strings uboot.img \| grep -E 'bl31-v1.44\|bl32-v2.15'` |

Do **not** pack with github rkbin master BL31 v1.46 / BL32 v2.16 without a separate OP-TEE/seal upgrade.

## Backup / rollback

Prior validated vendor pair: `backup/20260815T130431Z/` (see that README).  
Restore → `FACTORY_SKU=ynh960-p800 make build-img` → flash. Details: `docs/uboot-rkbin.md`.

## Verification (self-built uboot, 2026-08-15)

From uncompressed `u-boot` ELF after `make.sh rk3566_rk3568` (FIT gzip hides these strings):

```text
bootcmd=run rkimg_bootdev;boot_fit;run distro_bootcmd;
bl31-v1.44
bl32-v2.15
```

`boot_android` may still appear as a compiled command symbol; it must **not** precede `boot_fit` in default `bootcmd`.
