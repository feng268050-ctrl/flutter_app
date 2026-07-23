# mediamtx-binary-bundled-build Specification

## Purpose
TBD - created by archiving change camera-rtsp-mediamtx-proxy. Update Purpose after archive.
## Requirements
### Requirement: Reproducible MediaMTX build for Android ABI

The build pipeline SHALL provide a reproducible way to compile the MediaMTX server binary for Android **`arm64-v8a`** from a pinned upstream source revision recorded in repository metadata (tag or commit hash).

#### Scenario: Developer rebuilds MediaMTX

- **WHEN** a developer runs the documented build entrypoint (e.g. `make mediamtx`)
- **THEN** the build MUST produce an executable binary for `arm64-v8a` without manual ad-hoc steps not captured in the repo

### Requirement: Build output placement for APK assets

Before APK assembly, the build SHALL copy the compiled MediaMTX binary into `app/src/main/assets/mediamtx/arm64-v8a/mediamtx` and SHALL write a companion version file (e.g. `version.txt`) containing the MediaMTX semver used for runtime comparison.

#### Scenario: Release APK contains binary

- **WHEN** `assembleRelease` (or equivalent) runs after the MediaMTX build step
- **THEN** the resulting APK MUST include the binary and version file under `assets/mediamtx/arm64-v8a/`

### Requirement: Generated assets are not committed

The repository SHALL treat `app/src/main/assets/mediamtx/` as a generated output (e.g. via `.gitignore`) while still merging it into the APK at build time.

#### Scenario: Clean clone without prebuilt binary

- **WHEN** a developer clones the repository without pre-populated `assets/mediamtx/`
- **THEN** documentation MUST state that `make mediamtx` (or CI) is required before a camera-relay-capable APK can be built

### Requirement: License and notice

The build documentation SHALL record MediaMTX upstream version and license obligations (MIT) in project notice or docs consumed by release engineering.

#### Scenario: Release audit

- **WHEN** release engineering audits third-party binaries
- **THEN** MediaMTX version and license MUST be discoverable from repository docs tied to the build entrypoint

