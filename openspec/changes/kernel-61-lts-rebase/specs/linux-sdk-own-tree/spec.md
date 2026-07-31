## ADDED Requirements

### Requirement: Owned kernel-6.1 tracks documented 6.1 LTS pin

The owned SDK tree’s `kernel-6.1` Makefile `SUBLEVEL` (and resulting `uname -r`) SHALL match the product-documented 6.1 LTS pin from `kernel-61-lts-security` after this change is applied on a developer machine. Product DTS and patches continue to use **`overlay/kernel/` as git source of truth**; LTS stable merges land in the owned `linux-sdk/kernel-6.1` tree and are not a substitute for committing product deltas only under `linux-sdk/`.

#### Scenario: Makefile SUBLEVEL matches pin after merge

- **WHEN** a developer completes the LTS merge and refresh of the owned tree per this change
- **THEN** `linux-sdk/kernel-6.1/Makefile` `SUBLEVEL` equals the documented tip and product overlay still reapplies with `FORCE_PLATFORM_OVERLAY=1`

## MODIFIED Requirements

### Requirement: platform squash and apply-overlay thinning

Stable platform overlay content under `overlay/kernel/` and always-on device script patches SHALL be applied into the local owned `linux-sdk/` (squash helper or equivalent) so subsequent builds do not rely on re-copying those platform diffs on every run. When the ownership marker is present, `apply-overlay` MUST skip kernel DTS/config/patch apply and skipped device installs already owned by the tree unless `FORCE_PLATFORM_OVERLAY=1` (or equivalent) is set. Third-party and custom Buildroot package overlay paths (`overlay/buildroot/package/**`, `overlay/third-party/**`, and related `sync_*_package` helpers) MUST continue to be injected on every `apply-overlay`. After a 6.1 LTS baseline bump, developers MUST re-run forced platform overlay or squash so rebased `overlay/kernel/` content replaces the pre-bump squashed kernel deltas.

Until `linux-sdk/` is committed to git (S4), **`overlay/kernel/` remains the git source of truth** for product DTS/DTSI fragments and related kconfig fragments so colleagues can sync via PR. Developers MUST land shareable DT changes in `overlay/kernel/` and re-apply into the local SDK (`FORCE_PLATFORM_OVERLAY=1 make apply-overlay` or `make squash-linux-sdk-platform`). Boot device trees MUST NOT be stored under `oem/` (U-Boot loads FIT before `/oem` is mounted). Detail: `docs/linux-sdk-vendor-import.md`.

#### Scenario: owned tree skips kernel re-apply

- **WHEN** `linux-sdk` has the ownership marker and a developer runs `make apply-overlay` without forcing platform overlay
- **THEN** apply-overlay does not re-copy `overlay/kernel` patches into the SDK kernel tree (or no-ops that step) while still syncing custom BR packages from overlay

#### Scenario: third-party packages still overlay

- **WHEN** a developer changes a package under `overlay/buildroot/package/` and runs `make apply-overlay`
- **THEN** the package recipe is still installed into the SDK Buildroot package tree as before this change

#### Scenario: DT change synced via overlay

- **WHEN** a developer updates a product DTSI under `overlay/kernel/rockchip/` and runs `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or squash) on an owned tree
- **THEN** the corresponding files under the local SDK kernel DTS tree are updated from overlay

#### Scenario: post-LTS-bump forced re-apply

- **WHEN** the owned `kernel-6.1` tree has been merged to a new 6.1.y tip and overlay patches were rebased
- **THEN** a forced platform overlay or squash step is required so the SDK kernel tree picks up the rebased product deltas (plain `apply-overlay` skip MUST NOT be assumed sufficient)
