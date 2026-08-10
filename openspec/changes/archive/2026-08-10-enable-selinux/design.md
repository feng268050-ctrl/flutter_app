## Context

Device L1SZ2026070001 (and the product image generally) reports **no selinuxfs**, no `getenforce`, and no cmdline SELinux tokens. Git has zero SELinux wiring under `overlay/`. Buildroot baseline is **2025.02.x** and already vendors `package/libselinux` + `package/refpolicy`. Init is **systemd** (`lws_hmi_systemd.config`). Rootfs is **ext4** (`~600M` cap under a 1 GiB GPT slot). Bootloader is **prebuilt** Innohi/Rockchip U-Boot — product policy forbids casual `make build-uboot` on ynh960.

SELinux on Linux does not require U-Boot awareness: the kernel LSM + rootfs policy/labels are sufficient. Optional `selinux=` / `enforcing=` can live in DTS `bootargs` or `/etc/selinux/config`.

## Goals / Non-Goals

**Goals:**

- Ship a bootable image where SELinux is **loaded and Permissive** on ynh960 after kernel+rootfs upgrade.
- Keep U-Boot / MiniLoader / GPT unchanged.
- Preserve SELinux **security xattrs** through `make build-rootfs` and full-system `make upgrade` rootfs writes.
- Leave a clear path for a follow-up change to add product modules and eventually Enforcing.

**Non-Goals:**

- Enforcing mode as the product default.
- Custom domains for `hmi.service`, MediaMTX, `lws_ai`, GPIO HAL, cloud OTA watchers.
- Rewriting Secure Boot / AVB / `verifiedbootstate`.
- Android-style `androidboot.selinux=` dependency.
- Per-SKU kernel forks; emulator-only policy forks.
- Claiming compliance (e.g. Common Criteria) from this change alone.

## Decisions

### D1 — Permissive-first via Buildroot refpolicy state

**Choice:** Enable `BR2_PACKAGE_LIBSELINUX` + `BR2_PACKAGE_REFPOLICY` with `BR2_PACKAGE_REFPOLICY_POLICY_STATE_PERMISSIVE`. Prefer `/etc/selinux/config` as the mode source of truth over forcing `enforcing=` on cmdline.

**Alternatives:** (a) Enforcing immediately — rejected (upstream refpolicy will deny systemd/HMI paths). (b) Disabled policy state with only kernel compiled in — rejected (no AVC learning). (c) Custom git refpolicy fork from day one — deferred until AVC volume justifies it.

### D2 — Kernel fragment `ynh960-selinux.config`

**Choice:** New fragment under `overlay/kernel/rockchip/` enabling at least:

- `CONFIG_AUDIT=y`
- `CONFIG_SECURITY=y`
- `CONFIG_SECURITY_SELINUX=y`
- `CONFIG_SECURITY_SELINUX_BOOTPARAM=y`
- `CONFIG_SECURITY_SELINUX_DEVELOP=y`
- `CONFIG_DEFAULT_SECURITY_SELINUX=y`
- `CONFIG_LSM` including `selinux` (preserve other LSMs already enabled by the Rockchip baseline where present)

Wire into `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`.

**Alternatives:** Patch vendor defconfig in-tree — rejected (overlay SoT). Boot-disabled (`BOOTPARAM_VALUE=0`) only — acceptable as a soft landing if early bring-up fails; default preference is LSM on + userspace permissive.

### D3 — No U-Boot change; DTS bootargs only if needed

**Choice:** Do **not** touch `prebuilt/bootloader/` or `make build-uboot`. If kernel defaults + `/etc/selinux/config` are insufficient to load policy, append `selinux=1` (and keep `enforcing=0`) to `overlay/kernel/rockchip/ynh960-linux-root.dtsi` `bootargs` (and letter-B sibling if any). Prefer not adding cmdline tokens unless bring-up requires them.

**Alternatives:** U-Boot env `bootargs` injection — rejected (env CRC / vendor constraint risk).

### D4 — Chip fragment `lws_hmi_selinux.config` + defconfig include

**Choice:** New `overlay/buildroot/chips/lws_hmi_selinux.config` included from `rockchip_rk3566_rk3568_lws_hmi_defconfig`, matching OP-TEE/platform fragment style. Ship `policycoreutils` (or the minimal set that provides `getenforce` / `restorecon`) so operators can verify without ad-hoc binaries.

**Alternatives:** Fold into `lws_hmi_platform.config` — rejected (orthogonal; want an easy `#include` toggle). Host-only tools without target `getenforce` — rejected (acceptance needs on-device check).

### D5 — Rootfs labeling + xattr survival is a hard gate

**Choice:** Rely on Buildroot’s SELinux rootfs labeling when `libselinux`+`refpolicy` are enabled. After `make build-rootfs`, verify the published `output/firmware/<APP>/rootfs.img` still has `security.selinux` xattrs (e.g. `getfattr` in the build environment / loop mount). If packaging (`mkfs`, Docker export, OTA archive) strips xattrs, fix that path in this change — unlabeled rootfs makes permissive mode useless for learning.

**Alternatives:** Relabel on first boot only — possible fallback but slower and races with early services; prefer image-time labels.

### D6 — Size budget: measure, then trim tools if needed

**Choice:** Keep the existing `BR2_TARGET_ROOTFS_EXT2_SIZE="600M"` unless measurement shows SELinux packages overflow. Prefer dropping optional setools/python debug packages before raising the rootfs size.

**Alternatives:** Jump to 700M+/slot fill — only if policy+tools cannot fit after trim.

### D7 — Product policy modules are follow-up

**Choice:** This change ships upstream/Buildroot refpolicy modules only (plus whatever Buildroot auto-enables for selected packages). AVC collection during soak feeds a **future** change (`selinux-product-policy` or similar) for HMI/AI/MediaMTX domains and eventual Enforcing.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Rootfs exceeds 600M | Measure after enable; drop optional packages; only then adjust size/inodes |
| Packaging strips xattrs → all `unlabeled_t` | Gate on `getfattr` check of `rootfs.img`; fix tar/mkfs/export |
| systemd + refpolicy denials flood logs in permissive | Expected; document `ausearch`/`dmesg` filters; do not flip enforcing |
| Early boot hang if LSM on but policy missing | Ensure refpolicy installs; keep DEVELOP/BOOTPARAM; permissive config |
| OTA A/B leaves old unlabeled letter | Full-system upgrade writes inactive rootfs; both letters get labeled images over time |
| Emulator kernel fragment interaction | Shared `ynh960-selinux.config` applies when fragment list is shared; smoke optionally on emu |
| Operators try `setenforce 1` on incomplete policy | Docs: leave permissive; enforcing is a separate change |

## Migration Plan

1. Land kernel fragment + Buildroot fragment (git).
2. `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`
3. `make build-kernel`
4. Rebuild SELinux-related packages if stamps are stale, then `make build-rootfs`
5. Verify xattrs on `rootfs.img`; `scripts/verify-rootfs-overlay.sh` PASS
6. `make upgrade` on ynh960 → `getenforce` → `Permissive`; HMI still reaches multi-user
7. **Rollback:** remove `#include` + fragment from `RK_KERNEL_CFG_FRAGMENTS`, rebuild kernel+rootfs, upgrade (or flash previous artifacts). No GPT/U-Boot rollback required.

## Open Questions

1. Exact minimal target package set beyond `libselinux`+`refpolicy` (`policycoreutils` full vs busybox applets) — resolve during implementation by size vs `getenforce` availability.
2. Whether DTS `selinux=1` is required on this Rockchip 6.1 baseline or config alone loads policy — decide on first device boot.
3. Whether `/userdata` and `/oem` mounts need explicit contexts in this change or can wait for product-policy follow-up (default: wait; permissive soak is enough).
