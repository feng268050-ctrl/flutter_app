## Why

Shipped product kernels report **Linux 6.1.99** (Rockchip/Innohi `kernel-6.1` tree; device confirmed 2026-07-31). Upstream **6.1 LTS** tip at audit time was **6.1.180** — about **81** stable point releases (~two years) of security and bug fixes behind. The Linux kernel CVE team does **not** support cherry-picking individual CVE commits as the primary remediation; distributors are expected to track the LTS tip. Staying on 6.1.99 leaves known High findings (e.g. Bluetooth/tap-tun related CVEs fixed only after 6.1.99) and a large undocumented backlog of stable fixes that never listed a CVE ID in the ChangeLog.

**Prerequisite:** ~~Blocked on~~ **Unblocked by** platform **W5** multi-configuration FIT packaging (`openspec/changes/multi-board-fit-dt`, packaging + ynh960 regression done 2026-08-01). LTS work rebases the multi-board overlay/FIT layout (`board/rk356x-fit-boards.txt` + `overlay/kernel/`), not the legacy single-FDT ITS.

## What Changes

- Rebase/merge the owned **`linux-sdk/kernel-6.1`** tree from **6.1.99** to the current **6.1.y LTS tip** (floor at audit: **≥ 6.1.180**; lock exact tip at implement time).
- Treat the upgrade unit as **the full stable series** `v6.1.100`…`v6.1.<tip>` — **not** a short cherry-pick list of High CVEs in `overlay/kernel/patches/`.
- Rebase product-owned kernel deltas under **`overlay/kernel/`** (patches `0001–0008`, ynh960 DTS/config fragments) onto the new baseline; re-squash / `FORCE_PLATFORM_OVERLAY=1 apply-overlay` so colleagues stay in sync.
- Rebuild dual FIT (`boot.img` / `boot_b.img`) + rootfs as needed; deploy via existing A/B `make upgrade` path and verify `uname -r` matches the pin.
- Record the pinned `SUBLEVEL` / `uname -r` expectation and a post-upgrade smoke matrix (display, eth, Wi‑Fi/BT, USB gadget, HMI).
- Optional defense-in-depth (separate tasks): trim unused attack surface already off product need (e.g. unused network filesystems) — secondary to the LTS rebase.
- **Out of scope:** jumping to 6.6 / 6.12 / 6.18 LTS; Android GKI; enabling new subsystems for features; OpenSSL userspace bump (tracked by `openssl-cve-upgrade`).

## Capabilities

### New Capabilities

- `kernel-61-lts-security`: 6.1 LTS version floor/pin, no-primary-cherry-pick policy, overlay rebase + owned-tree workflow, build/upgrade verification, and post-merge advisory acceptance notes.

### Modified Capabilities

- `linux-sdk-own-tree`: Clarify that LTS stable merges land in owned `linux-sdk/kernel-6.1` while **`overlay/kernel/` remains git SoT** for product patches/DTS; document recording the baseline `SUBLEVEL` for colleagues.
- `buildroot-lws-hmi-image`: Shipped kernel FIT MUST report the pinned 6.1.y version (not 6.1.99) after this change.

## Impact

- Kernel: `linux-sdk/kernel-6.1` (gitignored owned tree), `overlay/kernel/patches/*`, `overlay/kernel/rockchip/*`, `scripts/apply-overlay.sh` / `squash-linux-sdk-platform`.
- Build/ship: `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or squash), `make build-kernel`, `make build-rootfs` when modules/firmware coupling requires it, `make upgrade` (A/B FIT + rootfs).
- Runtime regression focus: Weston/HMI, eth0, Wi‑Fi/BT (`aic8800`), USB gadget/SSH, NPU/VOP DT overlays, RTC/touch.
- Docs: `docs/linux-sdk-vendor-import.md` and AGENTS rebuild table if new Make helpers appear; otherwise extend vendor-import with the LTS pin note.
- Risk: Rockchip/Innohi vendor delta vs vanilla stable may conflict; design defines conflict triage and a staged merge (stable first, then re-apply vendor/product patches).
