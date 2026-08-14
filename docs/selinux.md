# SELinux (Cyber OS)

Product SELinux is enabled in **permissive** mode: kernel LSM + Buildroot
`libselinux` / `refpolicy` / `policycoreutils`. Enforcing and product domains
(HMI, AI daemon, MediaMTX, etc.) are **out of scope** until a follow-up change
after AVC soak.

## Source of truth

| Layer | Path |
|-------|------|
| Kernel fragment | `overlay/kernel/rockchip/ynh960-selinux.config` (in `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`) |
| Buildroot chip | `overlay/buildroot/chips/lws_hmi_selinux.config` (`#include` from `rockchip_rk3566_rk3568_lws_hmi_defconfig`) |
| Mode | `BR2_PACKAGE_REFPOLICY_POLICY_STATE_PERMISSIVE` → `/etc/selinux/config` |

**U-Boot is not modified.** Do not run `make build-uboot` for SELinux.

## Rebuild

```text
make apply-overlay
bash scripts/br-make-packages.sh selinux libselinux libsepol refpolicy policycoreutils libsemanage audit systemd
FORCE_KERNEL_IMAGE=1 make build-kernel
make build-rootfs
make upgrade
```

`audit` adds userspace `auditd` (Lynis ACCT-9628); kernel `CONFIG_AUDIT=y` is already on via `ynh960-selinux.config`.

`systemd` is listed because enabling `libselinux` flips Meson `-Dselinux=enabled`; stamp reuse would leave an SELinux-unaware PID 1.

### Wi‑Fi modules after enabling `CONFIG_SECURITY`

`CONFIG_SECURITY` inserts `inode->i_security` **before** `i_size`. AIC8800
`rwnx_load_firmware` uses inlined `i_size_read()`; a `.ko` built **without**
`CONFIG_SECURITY` and loaded into a SELinux kernel mis-reads `i_nlink` (usually
`1`) as the firmware file size → MD5 of one byte (`7fc56270…` = MD5(`A`)) →
`TAG err` → no `wlan0`.

`vermagic` still matches (`6.1.180 …`), so this is easy to miss. After flipping
`CONFIG_SECURITY` / SELinux fragments, **force-rebuild** in-tree Wi‑Fi modules
before `post-wifibt` copies them into `/vendor/lib/modules` (a plain
`make build-kernel` may reuse stale `aic8800_*.o`):

```bash
# inside SDK kernel tree (Docker: /work/sdk/kernel)
rm -f drivers/net/wireless/aic8800/aic8800_{bsp,fdrv,btlpm}/*.{o,ko}
# then make build-kernel && make build-rootfs
```

On-device symptom check: `dmesg | grep 'file md5'` — expect firmware MD5s from
OEM blobs (e.g. patch table `fefcc62c…`), not `7fc56270…`.

## On-device verify

```bash
getenforce          # expect: Permissive
sestatus            # policy loaded, mode permissive
ls /sys/fs/selinux
ls -Z /usr/bin/systemctl | head
dmesg | grep -i avc | tail
```

Do **not** `setenforce 1` on incomplete product policy.

## Size note (2026-08-10 bring-up)

`rootfs.img` remains **600M** (GPT slot 1 GiB). After SELinux packages + labeling,
debugfs showed ~49k free 4 KiB blocks (~190 MiB free) — no size bump required.
