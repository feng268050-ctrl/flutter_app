## ADDED Requirements

### Requirement: Startup compares bundled and installed library versions

On application startup (or an equivalent early lifecycle hook that runs once per process launch before user-dependent library features), the system SHALL discover the library file for each of `ai-library` and `process-library` under `assets/<artifact>/`, extract a semver **substring** from the filename per product naming (aligned with manifest `filename`, e.g. `工艺库_v1.0.0-beta.xlsx`). It SHALL parse and compare versions using the **same SemVer 2.0–compliant library** as OTA and all other version ordering in this change, via that library’s parse and compare APIs only (no bespoke ordering). It SHALL compare the bundled file’s version to the version parsed from the corresponding file under the app-private data directory for that artifact (same naming convention). If no data copy exists or the bundled version is greater than the installed version, the system SHALL run the import/update path for that artifact.

#### Scenario: First install imports from assets

- **WHEN** there is a bundled library file in assets and no matching library file in app data (or no semver-parsable file)
- **THEN** the system SHALL execute import for that artifact

#### Scenario: Older data version is upgraded from assets

- **WHEN** the bundled file semver is greater than the data directory file semver
- **THEN** the system SHALL execute import for that artifact

#### Scenario: Data is up to date

- **WHEN** the data directory file semver is greater than or equal to the bundled file semver
- **THEN** the system SHALL NOT replace the data copy solely based on the bundled asset

### Requirement: Process library import reuses pre-refactor OTA behavior

For `process-library`, the import/update logic executed after a positive version comparison SHALL follow the same behavioral path as the legacy OTA process-library upgrade (file handling, calls into existing import/persistence code, and user-visible failure modes), differing only in **how the source file is obtained** (from bundled assets / copy into workspace) rather than from the OTA downloader.

#### Scenario: Process library xlsx import parity

- **WHEN** startup triggers a process-library import from a bundled xlsx whose semver is newer than data
- **THEN** the resulting persisted process data SHALL be equivalent to what the legacy OTA process-library path would have produced for the same xlsx file

### Requirement: AI library import uses existing integration points

For `ai-library`, the system SHALL apply the same unpack/install steps used when the AI library was previously delivered through OTA (or the current canonical integration code path), triggered only when the semver comparison mandates an update.

#### Scenario: AI library update from assets

- **WHEN** the bundled AI archive semver is newer than the installed copy
- **THEN** the system SHALL install or replace the AI library content using the established integration logic
