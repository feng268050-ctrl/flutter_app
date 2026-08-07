## Context

Product userspace is built by Rockchip/Innohi **Buildroot** under owned (gitignored) `linux-sdk/buildroot/`. The tree currently exports `BR2_VERSION := 2024.02` — the previous Buildroot LTS line, now past upstream support.

Upstream Buildroot release model (as of 2026-08):

| Series | Role | EOL | Tip at propose |
|--------|------|-----|----------------|
| **2025.02.x** | **LTS** (3-year) | **March 2028** | **2025.02.16** |
| 2026.05.x | Three-month stable | September 2026 | 2026.05.1 |

Product overlays already assume a **2025.02-shaped** OpenSSL recipe (`scripts/apply-overlay.sh` comment: overlay ships Buildroot 2025.02.x set for OpenSSL 3.5.7) while the SDK base remains 2024.02. Custom packages stay on `overlay/buildroot/package/**` and are re-injected every `apply-overlay`. Rootfs uses Rockchip **external GCC 10.3** (`chips/lws_hmi_toolchain_external.config`), not Buildroot-internal toolchain compile.

Kernel 6.1 LTS rebase is a separate completed change; this change is **userspace Buildroot only**.

## Goals / Non-Goals

**Goals:**

- Move owned `linux-sdk/buildroot` onto **Buildroot 2025.02.x LTS** tip (floor **≥ 2025.02.16**; lock exact tag at implement).
- Preserve Rockchip board/package deltas needed for ynh960 rootfs and existing `make build-rootfs` / `build.sh` workflow.
- Keep **`overlay/buildroot/**` as git SoT** for chips fragments and package pins; rebase sync helpers as needed.
- Document a trackable version pin and a clean-output rebuild path for developers.
- Prove product smoke on ynh960 after A/B rootfs upgrade.

**Non-Goals:**

- Tracking **2026.05.x** (or master) as the product baseline in this change.
- Replacing the Rockchip external toolchain with Buildroot-built gcc/glibc.
- Committing `linux-sdk/` to git (S4).
- Kernel bumps, Flutter engine version bumps, or opportunistic package major upgrades beyond what the LTS merge and overlay re-apply require.
- Exhaustive CVE enumeration of every package between 2024.02 and 2025.02.16 as a gate (LTS tip catch-up **is** the gate for BR infrastructure + default recipes; product overlay pins remain authoritative for OpenSSL/GStreamer/BlueZ).

## Decisions

### D1 — Target = 2025.02.x LTS, not newest stable

**Choice:** Rebase to **2025.02.x** tip (≥ 2025.02.16).

**Reject:** Jumping to **2026.05.1** “latest stable.”

**Rationale:** Appliance needs multi-year security maintenance. Stable EOLs in ~2 months from propose date; LTS runs to March 2028 with monthly point releases. Future “move tip again” updates stay on the same series until the next LTS (2027.02).

### D2 — Remediation unit = LTS tip merge, not package cherry-picks

**Choice:** Bring the owned Buildroot tree to the **2025.02.x tip** (full series move from 2024.02 base), then re-apply product overlays.

**Reject:** Cherry-picking individual package bumps onto frozen 2024.02 as the primary path.

**Rationale:** Matches how we handled kernel 6.1 LTS; closes unnamed infrastructure/package fixes; aligns overlay OpenSSL 3.5 recipe with upstream package shape.

### D3 — Merge strategy (vendor Rockchip BR + upstream LTS)

Recommended sequence:

1. **Inventory:** Diff Rockchip `buildroot/` vs vanilla `2024.02` — board configs, `package/rockchip/**`, patches, `Config.in` hooks, `support/` / infra scripts, Innohi/RK extras.
2. **Import LTS tip:** Add upstream `buildroot.org` remote; check out / merge tag **`2025.02.<n>`** (locked at implement) into a work branch of owned `linux-sdk/buildroot`, **or** start from upstream 2025.02.<n> and re-drop Rockchip deltas (see alternative below).
3. **Conflict triage:** Prefer upstream LTS for generic packages/infra; preserve Rockchip behavior in `board/rockchip`, `package/rockchip`, Mali/MPP/RGA, and external-toolchain fragments.
4. **Re-apply product overlay:** `make apply-overlay`; fix broken sync helpers / Kconfig symbols renamed in 2025.02; adjust chips fragments if options moved.
5. **Clean rebuild:** `make clean-buildroot-output` → `make lunch` → rebuild overlay-pinned packages (`br-make-packages.sh` / runtime prebuilts as needed) → `make build-rootfs` → `make upgrade`.
6. **Pin docs:** Record locked version in `docs/linux-sdk-vendor-import.md` and `overlay/buildroot/BUILDROOT_VERSION` (one line, e.g. `2025.02.16`).

**Alternatives considered:**

| Approach | Pros | Cons |
|----------|------|------|
| **A. Merge upstream 2025.02.x into Rockchip 2024.02 tree** (preferred default) | Keeps RK history/bisect of vendor commits | Large conflict surface in shared packages |
| **B. Fresh upstream 2025.02.x + re-apply Rockchip package/board delta set** | Cleaner LTS base | Easy to miss silent RK patches; higher checklist burden |
| **C. Wait for Innohi SDK drop already on 2025.02** | Vendor-tested | Unknown schedule; blocks security timeline |

**Policy:** Prefer **A**; switch to **B** only if merge conflicts make the tree unmaintainable. Prefer vendor drop (**C**) only if it lands at **≥ tip floor** during implementation and still rebase product overlay.

### D4 — Keep external toolchain; do not rebuild glibc in-tree

**Choice:** Retain `lws_hmi_toolchain_external.config` + Rockchip `toolchain/arm_10_aarch64.config` unless 2025.02 breaks the fragment (then adapt the fragment, not switch to internal toolchain in this change).

**Rationale:** Avoids multi-hour toolchain rebuilds and decouples BR LTS from libc ABI churn; matches current product pipeline.

### D5 — Overlay package pins stay authoritative

OpenSSL / GStreamer / BlueZ / Meson / Flutter packages continue to live under `overlay/buildroot/package/` and override SDK recipes via `apply-overlay`. After the BR bump:

- Re-run sync helpers; stash obsolete Rockchip patches as today.
- **Force** package dirclean rebuilds — stamp reuse across major BR versions is undefined.
- Do not relax version floors already in `buildroot-libopenssl` / `buildroot-gstreamer-security` / `buildroot-bluez-security`.

### D6 — Version pin file for colleagues

Until S4 commits `linux-sdk/`, colleagues cannot see `BR2_VERSION` from git. Add:

- `overlay/buildroot/BUILDROOT_VERSION` — single line `2025.02.<n>`
- Section in `docs/linux-sdk-vendor-import.md` mirroring the kernel `KERNEL_6_1_SUBLEVEL` pattern

Optional later: `scripts/check-prebuilt.sh` or `verify-env` mention of expected BR version (nice-to-have, not a ship blocker).

### D7 — Acceptance bar

- `grep` / `make` shows `BR2_VERSION` **2025.02.x** matching the pin (not `2024.02`).
- `make apply-overlay` + `make build-rootfs` succeeds; `scripts/verify-rootfs-overlay.sh` PASS.
- Device A/B upgrade: HMI/Weston up; eth; Wi‑Fi or BT as applicable; USB gadget SSH; OpenSSL/GStreamer/BlueZ pins still report overlay versions; OTA verify path still works (openssl).
- Docs pin updated in the same PR as the owned-tree instructions.

## Risks / Trade-offs

- **[Risk] Hard conflicts in Rockchip-shared packages (systemd, weston, wpa, bluez, gst)** → Mitigation: staged merge (2025.02.0 → mid point → tip) if needed; preserve `package/rockchip` and board fragments first; escalate to approach B or vendor drop if blocked.
- **[Risk] Kconfig symbol renames break chips fragments / defconfig `#include` chain** → Mitigation: early `make lunch` / olddefconfig after merge; fix fragments in overlay before full package build.
- **[Risk] Host/Docker Buildroot host-tools break on macOS volume** → Mitigation: rebuild inside existing Docker `linux/amd64` path; refresh volume after clean; document `docker-volume-init` in migration.
- **[Risk] Prebuilt Flutter/GStreamer linked against old staging** → Mitigation: treat major BR bump like GStreamer security change — force `build-gstreamer` / eLinux / engine refreshes when staging changes; do not ship with stale prebuilt stamps.
- **[Risk] Silent reuse of 2024.02 `buildroot/output`** → Mitigation: require `clean-buildroot-output` in tasks and AGENTS/docs note; fail closed if `BR2_VERSION` mismatch detected (optional check script).
- **[Trade-off] LTS vs newest stable** → Slightly older packages than 2026.05; much longer support and monthly security point releases.

## Migration Plan

1. Land merge + overlay fixes on a feature branch; clean Buildroot output; full rootfs build in Docker/SDK.
2. `make upgrade` to inactive A/B slot; confirm try-boot and userspace smoke.
3. Update pin docs; announce to team that local SDK Buildroot must be rebased / re-extracted per change instructions (tree is gitignored — each machine applies the merge or follows a documented tarball/sync step).
4. **Rollback:** A/B boot previous rootfs letter; restore prior `linux-sdk/buildroot` from backup/vendor extract; do not mix 2024.02 and 2025.02 output dirs.

**Colleague sync (gitignored SDK):** Document in vendor-import: either (1) replay merge steps from a short runbook, or (2) replace `linux-sdk/buildroot` from a shared internal artifact once one exists. Overlay + pin file still ship via normal PR.

## Open Questions

1. Is there an **Innohi/Rockchip SDK drop** already on 2025.02.x that should become the preferred baseline if it appears before implement finishes? (Default: proceed with upstream merge; adopt vendor drop only if ≥ tip floor.)
2. Should `make check-linux-sdk` / a tiny script **fail** when `BR2_VERSION` ≠ `overlay/buildroot/BUILDROOT_VERSION`? (Recommend yes as a follow-up task if cheap.)
3. Exact **2025.02.\<n\>** tip at implement time — re-check https://buildroot.org/download.html and lock in pin file.
