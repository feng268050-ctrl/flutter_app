## MODIFIED Requirements

### Requirement: platform squash and apply-overlay thinning

Stable platform overlay content under `overlay/kernel/` and always-on device script patches SHALL be applied into the local owned `linux-sdk/` (squash helper or equivalent) so subsequent builds do not rely on re-copying those platform diffs on every run. When the ownership marker is present, `apply-overlay` MUST skip kernel DTS/config/patch apply and skipped device installs already owned by the tree unless `FORCE_PLATFORM_OVERLAY=1` (or equivalent) is set. Third-party and custom Buildroot package overlay paths (`overlay/buildroot/package/**`, `overlay/third-party/**`, and related `sync_*_package` helpers) MUST continue to be injected on every `apply-overlay`. This MUST include product GStreamer family pins under `overlay/buildroot/package/gstreamer1/` (and Rockchip `gstreamer1-rockchip` overlay when present) required by `buildroot-gstreamer-security`.

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
