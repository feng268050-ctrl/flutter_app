## Context

Product boards (ynh960 line) boot a Rockchip/Innohi **Linux 6.1** tree under owned `linux-sdk/kernel-6.1/` (`VERSION=6`, `PATCHLEVEL=1`, `SUBLEVEL=99`). Device smoke (2026-07-31) reported `Linux buildroot 6.1.99`. Upstream **6.1 LTS** tip the same day was **6.1.180** ([kernel.org releases](https://www.kernel.org/releases.json)).

Git-tracked product deltas live in **`overlay/kernel/`** (patches + `rockchip/*.dtsi` / `*.config`). Until S4, `linux-sdk/` stays gitignored; `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` / `make squash-linux-sdk-platform` injects overlay into the owned tree. Dual FIT (`boot.img` / `boot_b.img`) + A/B `make upgrade` ship the kernel.

Audit finding: cherry-picking a short High-CVE list undercounts the real gap (most stable fixes lack CVE IDs in ChangeLogs). Linux CVE announce guidance is to update to the **latest stable on the supported line**.

Enabled attack-surface notes on device (for regression priority, not for cherry-pick scope): `BT`, `CFG80211`, `USB_GADGET`/`USB_ETH`, `NFS_V4`, `IO_URING`, `USER_NS`, `NETFILTER`, `MODULES`.

## Goals / Non-Goals

**Goals:**

- Bring shipped `uname -r` to current **6.1.y LTS tip** (floor **≥ 6.1.180** at audit; exact tip locked at implement time).
- Absorb security/bugfix via **full stable merge**, not CVE cherry-picks as the primary path.
- Keep **`overlay/kernel/`** as colleague-syncable SoT for product patches/DTS; rebase them onto the new baseline.
- Prove boot + product smoke on ynh960 after upgrade; A/B rollback remains available.

**Non-Goals:**

- Moving to 6.6 / 6.12 / 6.18 (or mainline) in this change.
- Exhaustive NVD enumeration of every CVE fixed between 6.1.99 and tip as a gate (tip catch-up **is** the gate).
- Userspace OpenSSL bump (`openssl-cve-upgrade`).
- Reworking Wi‑Fi/BT vendor out-of-tree modules beyond “still builds and associates” smoke.

## Decisions

### D1 — Remediation unit = 6.1 LTS tip, not CVE cherry-picks

**Choice:** Merge/rebase upstream stable **`v6.1.99` → `v6.1.<tip>`** (all commits in that range) into the owned Rockchip tree.

**Reject:** Maintaining a growing `overlay/kernel/patches/cve-*.patch` stack for High CVEs only.

**Rationale:** Matches kernel CVE team guidance; closes unnamed stable fixes; keeps future updates as “move tip again.”

### D2 — Target version ladder

| Priority | Target | Notes |
|----------|--------|-------|
| **1** | Newest **6.1.y** on kernel.org at implement time | Must be **≥ 6.1.180** |
| **2** | If tip merge is blocked mid-series | Land the highest conflict-clean intermediate (document), continue in a follow-up — do **not** stop at 6.1.99 |

Record the locked version in `docs/linux-sdk-vendor-import.md` (and optionally a one-line pin under `overlay/kernel/` e.g. `KERNEL_6_1_SUBLEVEL=180`) so colleagues know the expected `uname -r`.

### D3 — Merge strategy for vendor + product deltas

Recommended sequence:

1. **Baseline inventory:** note Rockchip/Innohi unique commits/dirs (e.g. `innohi/`, rockchip DRM/NPU bits) vs vanilla 6.1.99; list product overlay patches `0001–0008` and DTS fragments.
2. **Import stable:** add `stable/linux-6.1.y` remote (or apply `patch-6.1.<n>` series); merge `v6.1.<tip>` into owned `kernel-6.1` (prefer merge commit for bisectability of vendor conflicts).
3. **Resolve conflicts** preferring upstream stable for generic code; preserve Rockchip/Innohi behavior in vendor paths; re-test compile often.
4. **Re-apply product overlay:** refresh `overlay/kernel/patches/*` so they apply cleanly on the new tree; update DTS if bindings changed.
5. **Squash/sync:** `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` or `make squash-linux-sdk-platform`.
6. **Build/ship:** `make build-kernel` → (rootfs if module ABI/`depmod` needs) `make build-rootfs` → `make upgrade`.

**Alternatives considered:** Replace entire tree with vanilla 6.1.180 then re-drop Rockchip — higher risk of losing vendor support. Vendor SDK drop that already includes a newer SUBLEVEL — prefer if Innohi provides one **≥ tip floor**, still rebase product overlay.

### D4 — Product patch set (must rebase)

Current overlay patches (names may gain fuzz; keep intent):

| Patch | Intent |
|-------|--------|
| `0001-drm-gem-handle-objects-without-funcs-on-release.patch` | DRM GEM release safety |
| `0004-gt9xx-prefer-dt-cfg-protocol-b.patch` | Touch |
| `0005-icplus-ip101a-disable-aps-ynh960.patch` | Ethernet PHY |
| `0006-rockchip-drm-skip-init-without-display-subsystem.patch` | DRM without display |
| `0007-rockchip-sip-skip-smc-without-rockchip-dt.patch` | SIP/SMC without RK DT |
| `0008-rk808-rtc-reenable-probe.patch` | RTC |

Plus `overlay/kernel/rockchip/ynh960-*.dtsi` / `*.config` and related fragments (NPU/VOP, USB, Wi‑Fi, etc.).

### D5 — Acceptance bar

- Device/emulator: `uname -r` matches pinned `6.1.<tip>` (not `6.1.99`).
- Smoke: HMI/Weston comes up; eth link/ping; Wi‑Fi or BT module load as applicable; USB gadget SSH; no regress on product DT features (display, touch, NPU supply wiring).
- Security narrative: “tracking 6.1 LTS tip `<version>` as of `<date>`” — optional spot-check that previously cited High examples (e.g. BT/tap fixes after 6.1.99) are present via version floor, not per-CVE cherry-pick CI.

### D6 — Optional hardening (secondary)

After LTS lands, consider kconfig trims for unused surfaces (e.g. NFS if unused on appliance) via existing `ynh960-kernel-trim.config` patterns. **Must not** replace the LTS merge.

## Risks / Trade-offs

- **[Risk] Hard conflicts between Rockchip DRM/NPU and stable** → Mitigation: merge in stages (e.g. to 6.1.120, 6.1.150, tip); isolate vendor directories; escalate to vendor SDK refresh if blocked.
- **[Risk] Out-of-tree Wi‑Fi/BT (`aic8800`) breaks on newer 6.1** → Mitigation: early module build smoke; pin or patch module in follow-up without rolling back whole LTS.
- **[Risk] Overlay patches fail to apply** → Mitigation: rebase patches in git SoT before squash; CI/dev checklist includes `apply-overlay` dry run.
- **[Risk] Silent ship of old FIT** → Mitigation: gate on `uname -r`; A/B try-boot confirms new letter.
- **[Trade-off] Full merge vs cherry-pick** → Larger one-time integration cost; much lower long-term CVE debt.

## Migration Plan

1. Land merge + rebased overlay on a feature branch; build kernel in Docker/SDK.
2. `make upgrade` to inactive A/B slot; confirm try-boot and `uname -r`.
3. Run smoke matrix; fix blockers; only then promote as default product kernel pin in docs.
4. **Rollback:** A/B boot previous letter / reflash prior `boot.img` + matching modules rootfs if module ABI shifted.

## Open Questions

- Exact **6.1.y tip** on the day of implementation (re-read kernel.org).
- Whether a newer **Innohi/Rockchip SDK** drop already contains SUBLEVEL ≥ floor (prefer vendor-aligned base if so).
- Whether `make build-rootfs` is mandatory every kernel bump (yes if in-tree modules are packaged into rootfs; confirm current packaging path).
- Emulator (`p32` / virtio) kernel fragment compatibility with the new tip — include in smoke or defer with note.
