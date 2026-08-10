## ADDED Requirements

### Requirement: Buildroot LTS rebases land in owned tree with overlay SoT

Buildroot **2025.02.x LTS** baseline rebases SHALL land in owned `linux-sdk/buildroot` (gitignored until S4). Git-tracked product Buildroot content under **`overlay/buildroot/`** (chips fragments, `package/**` pins, version pin file) remains the colleague-syncable source of truth and MUST continue to be injected by `make apply-overlay` on every run. After a Buildroot major/LTS baseline bump, developers MUST re-run `make apply-overlay` and a clean Buildroot output rebuild so overlay recipes and defconfig fragments replace pre-bump SDK state. The vendor-import document SHALL record the locked Buildroot tip alongside the existing kernel LTS pin notes.

#### Scenario: apply-overlay still syncs packages after BR LTS bump

- **WHEN** owned `linux-sdk/buildroot` has been moved to the pinned 2025.02.x tip and a developer runs `make apply-overlay`
- **THEN** overlay custom packages (at least libopenssl, GStreamer family, BlueZ, Flutter pins when present) are still installed into the new SDK Buildroot package tree

#### Scenario: vendor-import records Buildroot tip

- **WHEN** a developer opens `docs/linux-sdk-vendor-import.md` after this change
- **THEN** the document records the expected Buildroot 2025.02.x tip (and points at the git-tracked pin file when present)
