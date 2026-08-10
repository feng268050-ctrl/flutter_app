## Why

Cyber OS on ynh960 currently boots with **no SELinux LSM**, no policy, and no userspace tools (`getenforce` / selinuxfs absent). Product services (HMI, MediaMTX, AI daemon, SSH, network) all run under traditional DAC only. Enabling SELinux in **permissive** mode first gives a measurable MAC foundation and AVC telemetry without risking boot or OTA regressions, while keeping the existing prebuilt U-Boot path unchanged.

## What Changes

- Add a ynh960 **kernel kconfig fragment** that enables SELinux (and required AUDIT/LSM wiring) under `overlay/kernel/`.
- Add a Buildroot chip fragment **`lws_hmi_selinux.config`** (`libselinux` + `refpolicy`, default **permissive**) and `#include` it from `rockchip_rk3566_rk3568_lws_hmi_defconfig`.
- Ship enough userspace to verify mode on device (`getenforce` / selinuxfs) and collect AVC denials during permissive soak.
- Ensure **ext4 rootfs image build and OTA packaging preserve security xattrs** so labeled files survive `make build-rootfs` / `make upgrade`.
- Document device acceptance (`getenforce=Permissive`) and explicit **non-goals**: no U-Boot rebuild; no product enforcing policy for HMI/AI/GPIO in this change.

## Capabilities

### New Capabilities

- `linux-selinux`: Kernel SELinux LSM enablement on the product 6.1 tree, boot/runtime mode (permissive first), and on-device acceptance without requiring bootloader changes.
- `buildroot-selinux`: Buildroot packages, refpolicy default state, rootfs labeling, and xattr preservation through image/OTA paths for the lws_hmi profile.

### Modified Capabilities

- `buildroot-lws-hmi-image`: Product defconfig composition SHALL include the SELinux chip fragment; rootfs size budget MUST still fit the existing GPT/OTA constraints after SELinux packages.

## Impact

- **Kernel:** `overlay/kernel/rockchip/ynh960-selinux.config` (name TBD in design) wired into `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`; rebuild via `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` + `make build-kernel`.
- **Buildroot:** new `overlay/buildroot/chips/lws_hmi_selinux.config`; defconfig `#include`; package rebuild stamps for `libselinux` / `refpolicy` (+ tools as needed).
- **Rootfs / OTA:** verify `rootfs.img` retains SELinux xattrs; adjust packaging scripts only if current tar/mkfs path strips them.
- **Bootloader:** **no change** — continue Innohi/prebuilt U-Boot; optional `selinux=` / `enforcing=` only via DTS bootargs or `/etc/selinux/config` if needed.
- **Apps / HAL:** no Dart API change in this change; product domains (HMI, MediaMTX, AI) stay unlabeled/permissive until a follow-up policy change.
- **Emulator:** follow board kernel fragment if shared; no separate virt-only SELinux policy in this change.
- **Docs:** AGENTS rebuild table / short SELinux note if operators need verify commands.
