## ADDED Requirements

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

Stable platform overlay content under `overlay/kernel/` and always-on device script patches SHALL be applied into the local owned `linux-sdk/` (squash helper or equivalent) so subsequent builds do not rely on re-copying those platform diffs. When the ownership marker is present, `apply-overlay` MUST skip kernel DTS/config/patch apply and skipped device installs already owned by the tree. Third-party and custom Buildroot package overlay paths (`overlay/buildroot/package/**`, `overlay/third-party/**`, and related `sync_*_package` helpers) MUST continue to be injected on every `apply-overlay`. New kernel platform patches MUST NOT be added under `overlay/kernel/` once squash lands (delete-only policy).

#### Scenario: owned tree skips kernel re-apply

- **WHEN** `linux-sdk` has the ownership marker and a developer runs `make apply-overlay`
- **THEN** apply-overlay does not re-copy `overlay/kernel` patches into the SDK kernel tree (or no-ops that step) while still syncing custom BR packages from overlay

#### Scenario: third-party packages still overlay

- **WHEN** a developer changes a package under `overlay/buildroot/package/` and runs `make apply-overlay`
- **THEN** the package recipe is still installed into the SDK Buildroot package tree as before this change

### Requirement: linux-sdk remains untracked

The repository `.gitignore` MUST continue to ignore `linux-sdk/`. This change MUST NOT add the SDK tree to the git index. Optional `.cursorignore` MAY list `linux-sdk/` to reduce IDE indexing load.

#### Scenario: gitignore still lists linux-sdk

- **WHEN** a developer inspects repo-root `.gitignore`
- **THEN** a `linux-sdk/` ignore rule is present
