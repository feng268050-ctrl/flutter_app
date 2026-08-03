# linux-sdk-own-tree Specification

## Purpose
Whitelist, trim, vendor-import records, size/forbid gates, and owned-tree layout for the Rockchip platform `linux-sdk/` (still gitignored until S4).
## Requirements
### Requirement: linux-sdk whitelist and size gate

The repository SHALL provide a tracked whitelist (`board/linux-sdk-whitelist.txt` or equivalent) describing keep roots, forbidden top-level directories, and external slim/keep rules for the owned Rockchip `linux-sdk/` tree. A host script (`make check-linux-sdk` / `scripts/check-linux-sdk-whitelist.sh`) SHALL fail when forbidden directories or known oversized blobs remain under `linux-sdk/`, and SHALL print a size summary. The gate SHALL ignore Buildroot download/output caches (`buildroot/dl/`, `buildroot/output/`, `output/`) when judging source-tree size band.

#### Scenario: untrimmed tree fails gate

- **WHEN** a developer runs `make check-linux-sdk` against an untrimmed full vendor SDK that still contains `debian/`, `ubuntu/`, or `yocto/`
- **THEN** the command exits non-zero and reports the forbidden paths

#### Scenario: trimmed tree passes gate

- **WHEN** a developer runs `make check-linux-sdk` after a successful `make trim-linux-sdk`
- **THEN** the command exits zero and reports no forbidden top-level directories

### Requirement: trim produces a buildable owned tree

The build system SHALL provide `make trim-linux-sdk` (`scripts/trim-linux-sdk.sh`) that deletes forbid-list content, slims `external/libmali` to the aarch64 wayland-gbm product need, keeps `rknpu2/runtime` while dropping toolkit/examples/doc bloat when present, and removes unused externals per whitelist. By default trim MUST preserve `buildroot/dl/`, `buildroot/output/`, and `output/`. Optional `TRIM=1` on `make extract-linux-sdk` SHALL run trim after extract. Trim SHALL install vendor-import documentation into the local tree and set an ownership marker used by apply-overlay.

#### Scenario: trim reduces forbid dirs

- **WHEN** a developer runs `make trim-linux-sdk` on a full vendor tree
- **THEN** `debian/`, `ubuntu/`, `yocto/`, top-level `docs/`, and `app/` are absent (or documented as keep exceptions) and the ownership marker exists

#### Scenario: extract with TRIM

- **WHEN** a developer runs `TRIM=1 make extract-linux-sdk SRC=<volumes>`
- **THEN** the extracted `linux-sdk/` is trimmed before the command completes successfully

### Requirement: vendor import record

The repository SHALL track canonical vendor-import documentation under `docs/` (copied into local `linux-sdk/VENDOR_IMPORT.md` by trim/extract). The document SHALL record blueprint identity (package/name/date), whitelist reference, trim workflow, Docker volume refresh note, and deferred git/LFS commit policy (tree remains gitignored).

#### Scenario: docs present in repo

- **WHEN** a developer opens `docs/linux-sdk-vendor-import.md`
- **THEN** blueprint/import/trim/git-defer guidance is present without requiring a committed `linux-sdk/` tree

### Requirement: platform squash and apply-overlay thinning

Stable platform overlay content under `overlay/kernel/` and always-on device script patches SHALL be applied into the local owned `linux-sdk/` (squash helper or equivalent) so subsequent builds do not rely on re-copying those platform diffs on every run. When the ownership marker is present, `apply-overlay` MUST skip kernel DTS/config/patch apply and skipped device installs already owned by the tree unless `FORCE_PLATFORM_OVERLAY=1` (or equivalent) is set. Third-party and custom Buildroot package overlay paths (`overlay/buildroot/package/**`, `overlay/third-party/**`, and related `sync_*_package` helpers) MUST continue to be injected on every `apply-overlay`. This MUST include product GStreamer family pins under `overlay/buildroot/package/gstreamer1/` (and Rockchip `gstreamer1-rockchip` overlay when present) required by `buildroot-gstreamer-security`. After a 6.1 LTS baseline bump, developers MUST re-run forced platform overlay or squash so rebased `overlay/kernel/` content replaces the pre-bump squashed kernel deltas.

Until `linux-sdk/` is committed to git (S4), **`overlay/kernel/` remains the git source of truth** for product DTS/DTSI fragments and related kconfig fragments so colleagues can sync via PR. Developers MUST land shareable DT changes in `overlay/kernel/` and re-apply into the local SDK (`FORCE_PLATFORM_OVERLAY=1 make apply-overlay` or `make squash-linux-sdk-platform`). Boot device trees MUST NOT be stored under `oem/` (U-Boot loads FIT before `/oem` is mounted). Detail: `docs/linux-sdk-vendor-import.md`.

#### Scenario: owned tree skips kernel re-apply

- **WHEN** `linux-sdk` has the ownership marker and a developer runs `make apply-overlay` without forcing platform overlay
- **THEN** apply-overlay does not re-copy `overlay/kernel` patches into the SDK kernel tree (or no-ops that step) while still syncing custom BR packages from overlay

#### Scenario: third-party packages still overlay

- **WHEN** a developer changes a package under `overlay/buildroot/package/` and runs `make apply-overlay`
- **THEN** the package recipe is still installed into the SDK Buildroot package tree as before this change

#### Scenario: GStreamer overlay still injected

- **WHEN** `overlay/buildroot/package/gstreamer1/` exists and a developer runs `make apply-overlay` on an owned tree
- **THEN** the SDK `buildroot/package/gstreamer1/` recipes are updated from overlay even when platform kernel squash steps are skipped

#### Scenario: DT change synced via overlay

- **WHEN** a developer updates a product DTSI under `overlay/kernel/rockchip/` and runs `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` (or squash) on an owned tree
- **THEN** the corresponding files under the local SDK kernel DTS tree are updated from overlay

#### Scenario: post-LTS-bump forced re-apply

- **WHEN** the owned `kernel-6.1` tree has been merged to a new 6.1.y tip and overlay patches were rebased
- **THEN** a forced platform overlay or squash step is required so the SDK kernel tree picks up the rebased product deltas (plain `apply-overlay` skip MUST NOT be assumed sufficient)

### Requirement: linux-sdk remains untracked

The repository `.gitignore` MUST continue to ignore `linux-sdk/`. This change MUST NOT add the SDK tree to the git index. Optional `.cursorignore` MAY list `linux-sdk/` to reduce IDE indexing load.

#### Scenario: gitignore still lists linux-sdk

- **WHEN** a developer inspects repo-root `.gitignore`
- **THEN** a `linux-sdk/` ignore rule is present

### Requirement: Multi-board DTS inventory in overlay SoT

Until S4 commit of `linux-sdk/`, git SoT under `overlay/kernel/` SHALL support **multiple** product board DTS/DTSI sets for the SoC family (not only `ynh960-*` includes). `apply-overlay` / squash SHALL install all inventoried board device-tree sources needed to build the corresponding DTBs for the shared family `Image`. Colleagues MUST sync board DT changes via overlay PRs the same way as today’s ynh960 fragments.

#### Scenario: Overlay lists more than one board target

- **WHEN** the SoC-family board inventory contains more than one board id
- **THEN** `overlay/kernel/` (and apply-overlay wiring) SHALL provide the DTS/DTSI inputs for each listed board
- **AND** `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` SHALL install those inputs into the owned SDK tree used by `make build-kernel`

### Requirement: Owned kernel-6.1 tracks documented 6.1 LTS pin

The owned SDK tree’s `kernel-6.1` Makefile `SUBLEVEL` (and resulting `uname -r`) SHALL match the product-documented 6.1 LTS pin from `kernel-61-lts-security` after this change is applied on a developer machine. Product DTS and patches continue to use **`overlay/kernel/` as git source of truth**; LTS stable merges land in the owned `linux-sdk/kernel-6.1` tree and are not a substitute for committing product deltas only under `linux-sdk/`.

#### Scenario: Makefile SUBLEVEL matches pin after merge

- **WHEN** a developer completes the LTS merge and refresh of the owned tree per this change
- **THEN** `linux-sdk/kernel-6.1/Makefile` `SUBLEVEL` equals the documented tip and product overlay still reapplies with `FORCE_PLATFORM_OVERLAY=1`

