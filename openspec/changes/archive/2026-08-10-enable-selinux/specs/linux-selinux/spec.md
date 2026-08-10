## ADDED Requirements

### Requirement: Product kernel enables SELinux LSM

The ynh960 product kernel SHALL enable the SELinux Linux Security Module via an overlay kconfig fragment under `overlay/kernel/rockchip/` (e.g. `ynh960-selinux.config`) that is listed in `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`. The fragment MUST enable at least `CONFIG_SECURITY_SELINUX`, auditing support required by SELinux, and boot-time SELinux controls suitable for development (`CONFIG_SECURITY_SELINUX_BOOTPARAM` and `CONFIG_SECURITY_SELINUX_DEVELOP`). The shipped kernel MUST NOT leave SELinux compiled out.

#### Scenario: Fragment wired into board defconfig

- **WHEN** `board/ynh960_defconfig` is inspected after this change
- **THEN** `RK_KERNEL_CFG_FRAGMENTS` includes the SELinux overlay fragment filename
- **AND** that fragment file exists under `overlay/kernel/rockchip/`

#### Scenario: Running kernel exposes selinuxfs

- **WHEN** a ynh960 board boots a kernel+rootfs built after this change and SELinux is not cmdline-disabled
- **THEN** `/sys/fs/selinux` is present (selinuxfs mounted or mountable)
- **AND** the kernel configuration used for that Image has `CONFIG_SECURITY_SELINUX=y`

### Requirement: Default runtime mode is Permissive

On first product enablement, SELinux SHALL run in **Permissive** mode so denials are logged without blocking systemd, HMI, or debug SSH. The product MUST NOT ship Enforcing as the default mode in this change. Mode MAY be selected via Buildroot refpolicy policy state (`/etc/selinux/config`) and/or kernel cmdline; either path MUST yield Permissive unless an operator explicitly overrides on a debug image.

#### Scenario: getenforce reports Permissive

- **WHEN** an operator SSHs to a board upgraded with this change’s kernel and rootfs
- **THEN** `getenforce` (or equivalent) reports `Permissive`
- **AND** multi-user boot still reaches the HMI stack

### Requirement: Bootloader is unchanged for SELinux enablement

Enabling SELinux MUST NOT require rebuilding or replacing the prebuilt U-Boot / MiniLoader used by ynh960 factory and OTA paths. Product bootargs changes for SELinux, if any, MUST be applied through device-tree `bootargs` under `overlay/kernel/` (or userspace `/etc/selinux/config`), not through U-Boot environment binary patches.

#### Scenario: No uboot rebuild required

- **WHEN** implementers list rebuild steps for this change
- **THEN** the required sequence includes kernel and rootfs rebuild/upgrade
- **AND** MUST NOT require `make build-uboot` or rewriting `prebuilt/bootloader/`
