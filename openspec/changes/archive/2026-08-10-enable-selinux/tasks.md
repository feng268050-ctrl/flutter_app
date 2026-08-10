## 1. Kernel SELinux fragment

- [x] 1.1 Add `overlay/kernel/rockchip/ynh960-selinux.config` with `CONFIG_AUDIT`, `CONFIG_SECURITY`, `CONFIG_SECURITY_SELINUX`, `CONFIG_SECURITY_SELINUX_BOOTPARAM`, `CONFIG_SECURITY_SELINUX_DEVELOP`, `CONFIG_DEFAULT_SECURITY_SELINUX`, and an LSM list that includes `selinux`
- [x] 1.2 Append `ynh960-selinux.config` to `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`
- [x] 1.3 Confirm no U-Boot / `prebuilt/bootloader` edits are required; leave DTS `bootargs` unchanged unless device bring-up proves cmdline `selinux=1` is needed

## 2. Buildroot SELinux packages

- [x] 2.1 Add `overlay/buildroot/chips/lws_hmi_selinux.config` enabling `BR2_PACKAGE_LIBSELINUX`, `BR2_PACKAGE_REFPOLICY`, permissive policy state, and the minimal tools package set that provides on-device `getenforce`
- [x] 2.2 `#include "chips/lws_hmi_selinux.config"` from `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig`
- [x] 2.3 After `make apply-overlay`, rebuild SELinux-related packages if Buildroot stamps would reuse pre-SELinux builds (`bash scripts/br-make-packages.sh …` as needed)

## 3. Image labeling and size

- [x] 3.1 Run `make build-rootfs` and confirm `scripts/verify-rootfs-overlay.sh` PASS
- [x] 3.2 Verify `output/firmware/<APP>/rootfs.img` retains `security.selinux` xattrs (loop mount / `getfattr`); fix packaging/export paths if labels are stripped
- [x] 3.3 Record rootfs size vs `600M` / GPT slot; trim optional SELinux debug packages before raising `BR2_TARGET_ROOTFS_EXT2_SIZE`

## 4. Kernel build and device acceptance

- [x] 4.1 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` then `make build-kernel`
- [x] 4.2 Deploy with `make upgrade` (kernel + rootfs) to ynh960
- [x] 4.3 On device: confirm `/sys/fs/selinux` exists, `getenforce` → `Permissive`, HMI reaches multi-user, USB-SSH still works
- [x] 4.4 Capture a short AVC sample (`dmesg` / audit) for the follow-up product-policy change; do **not** switch to Enforcing

## 5. Docs and operator notes

- [x] 5.1 Add a brief note (README / docs / AGENTS rebuild row as appropriate) for SELinux fragment + chip config rebuild commands and on-device verify (`getenforce`)
- [x] 5.2 Document explicit non-goals: no `make build-uboot`; Enforcing + product domains are a separate change
