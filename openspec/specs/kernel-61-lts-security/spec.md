# kernel-61-lts-security Specification

## Purpose
TBD - created by archiving change kernel-61-lts-rebase. Update Purpose after archive.
## Requirements
### Requirement: Shipped kernel tracks 6.1 LTS tip

The product kernel SHALL be based on the Linux **6.1** long-term stable line and SHALL ship a version whose `SUBLEVEL` is at least **180** (i.e. `uname -r` reports `6.1.180` or newer 6.1.y). The exact tip SHALL be locked at implementation time to the newest 6.1.y available from kernel.org (or an Innohi/Rockchip SDK base that already meets this floor). The shipped version MUST NOT remain `6.1.99`.

#### Scenario: Device reports pinned 6.1.y

- **WHEN** a board is upgraded with the kernel produced by this change
- **THEN** `uname -r` matches the documented 6.1.y pin and is not `6.1.99`

### Requirement: Stable series merge is the primary security remediation

Security catch-up for the 6.1 line SHALL be performed by merging or rebasing upstream stable commits from the previous product baseline through the pinned tip (the full `v6.1.<old+1>`…`v6.1.<tip>` series). The project MUST NOT treat a short list of individually cherry-picked CVE patches under `overlay/kernel/patches/` as the primary remediation for this backlog. Overlay patches remain allowed for **product-specific** fixes (board, DRM quirks, PHY, RTC, etc.).

#### Scenario: No CVE-only primary patch stack

- **WHEN** this change’s kernel security plan is inspected
- **THEN** the planned upgrade path is a 6.1 LTS tip merge/rebase, not a primary stack of `cve-*.patch` cherry-picks replacing that merge

### Requirement: Product overlay kernel deltas rebase onto the new baseline

Product-owned kernel changes under `overlay/kernel/` (including numbered patches and `rockchip/` DTS and kconfig fragments) SHALL apply cleanly to the post-merge `linux-sdk/kernel-6.1` tree via `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` or `make squash-linux-sdk-platform`. Patch fuzz that breaks apply MUST be fixed in overlay before the change is accepted.

#### Scenario: apply-overlay succeeds after rebase

- **WHEN** a developer runs `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` after the LTS merge and overlay rebase
- **THEN** product patches and DTS fragments install into the SDK kernel tree without manual patch reject piles

### Requirement: Kernel upgrade verification includes boot and product smoke

After building dual FIT images and deploying via the existing A/B upgrade path, verification MUST confirm the new kernel boots the HMI stack and exercises product-critical I/O: display/touch path, Ethernet, Wi‑Fi and/or Bluetooth module load as applicable, and USB gadget debug access when enabled.

#### Scenario: ynh960 smoke after upgrade

- **WHEN** `make build-kernel` artifacts are deployed with `make upgrade` (or equivalent A/B FIT apply) to ynh960
- **THEN** the device boots to HMI, `uname -r` matches the pin, and eth / wireless-or-BT / USB gadget smoke checks required by the implementing tasks pass

### Requirement: Document the pinned kernel SUBLEVEL for colleagues

Until `linux-sdk/` is committed, the repository SHALL document the expected Linux 6.1.y pin (SUBLEVEL / `uname -r`) in `docs/linux-sdk-vendor-import.md` and/or an overlay-adjacent pin file under `overlay/kernel/` so developers know which stable tip the owned tree must track.

#### Scenario: Pin is discoverable without reading SDK Makefile

- **WHEN** a developer without a populated `linux-sdk/` reads the documented pin location
- **THEN** they can determine the required `6.1.<tip>` version for builds

