## ADDED Requirements

### Requirement: lws_hmi Buildroot enables libselinux and refpolicy

The product Buildroot profile SHALL enable SELinux userspace via a dedicated chip fragment `overlay/buildroot/chips/lws_hmi_selinux.config` that turns on at least `BR2_PACKAGE_LIBSELINUX` and `BR2_PACKAGE_REFPOLICY`, with default policy state **permissive** (`BR2_PACKAGE_REFPOLICY_POLICY_STATE_PERMISSIVE` or equivalent). The fragment MUST be `#include`d from `rockchip_rk3566_rk3568_lws_hmi_defconfig`. The rootfs MUST install a policy under `/etc/selinux/` and MUST provide an on-device way to query enforcing mode (e.g. `getenforce` from policycoreutils or an approved equivalent).

#### Scenario: Defconfig includes selinux fragment

- **WHEN** `overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig` is inspected after this change
- **THEN** it `#include`s `chips/lws_hmi_selinux.config`

#### Scenario: Rootfs has policy and getenforce

- **WHEN** `make build-rootfs` completes for the default `APP`
- **THEN** the target rootfs contains SELinux policy configuration under `/etc/selinux/`
- **AND** an operator can run `getenforce` on a deployed board (binary present on PATH)

### Requirement: Rootfs image preserves SELinux security xattrs

The published ext4 `rootfs.img` used by `make upgrade` / `make build-img` MUST retain `security.selinux` extended attributes written during Buildroot image assembly. Host packaging, Docker export, and OTA archive steps MUST NOT strip those xattrs from the rootfs image payload. If a packaging path is found to drop xattrs, that path MUST be fixed in this change before acceptance.

#### Scenario: rootfs.img has security.selinux labels

- **WHEN** a developer inspects `output/firmware/<APP>/rootfs.img` after `make build-rootfs` (via loop mount or equivalent)
- **THEN** at least one regular file under the image root shows a non-empty `security.selinux` xattr
- **AND** `/etc/selinux` policy files in the image are labeled (not entirely unlabeled)

#### Scenario: Upgraded rootfs still has labels

- **WHEN** a board applies a full-system `make upgrade` that writes the new rootfs letter and reboots into it
- **THEN** `ls -Z` / `getfattr -n security.selinux` on a system binary (e.g. `/usr/bin/systemctl` or `/sbin/init`) shows a SELinux label
- **AND** the board remains in Permissive mode

### Requirement: SELinux packages respect rootfs size gates

Enabling SELinux packages MUST keep the published `rootfs.img` within the existing product GPT/OTA size gates for `rootfs_a`/`rootfs_b` (and the Buildroot `BR2_TARGET_ROOTFS_EXT2_SIZE` budget unless that budget is explicitly raised in the same change with documented rationale). Optional SELinux debug packages (setools/python helpers) MUST be omitted if they are the cause of overflow.

#### Scenario: verify-rootfs-overlay still passes

- **WHEN** `make build-rootfs` runs after SELinux packages are enabled
- **THEN** `scripts/verify-rootfs-overlay.sh` reports PASS
- **AND** rootfs size verification against the GPT slot still succeeds
