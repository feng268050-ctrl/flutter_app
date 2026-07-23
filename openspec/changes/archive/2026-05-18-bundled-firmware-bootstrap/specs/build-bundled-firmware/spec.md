## ADDED Requirements

### Requirement: Build copies firmware bin from repository firmware directory

The build pipeline SHALL copy control-card firmware binaries from the repository-root `firmware/` directory into `app/src/main/assets/firmware/` before APK assembly.

- The build SHALL include only files whose names match the project firmware naming convention `LSW01H####S####.bin` (four decimal digits for hardware after `H`, four for software after `S`).
- When multiple matching files exist, the build SHALL select exactly one firmware using the project’s filename integer rules (HW and SW integer extraction from the `LSW01H####S####.bin` format) and SHALL package only the latest candidate by maximum `softwareVersion` (SW), tie-breaking by maximum `hardwareVersion` (HW).
- Before copying the selected file, the build SHALL delete the entire `app/src/main/assets/firmware/` directory (including any stale files or subdirectories), then recreate it and write only the selected `.bin`.

#### Scenario: Single valid bin is bundled

- **WHEN** `firmware/LSW01H1000S1013.bin` exists and no other matching bins exist
- **THEN** the build SHALL place `app/src/main/assets/firmware/LSW01H1000S1013.bin` before APK assembly

#### Scenario: Multiple matching bins select latest

- **WHEN** `firmware/` contains two or more files matching `LSW01H####S####.bin`
- **THEN** the build SHALL select the firmware with the maximum software version among candidates and package only that file

#### Scenario: Missing firmware directory does not fail build

- **WHEN** `firmware/` has no matching `.bin` files
- **THEN** the build SHALL complete and the APK MAY omit `assets/firmware/`

### Requirement: Generated firmware assets directory is ignored by Git

The repository SHALL list `app/src/main/assets/firmware/` (or equivalent path under the app module) in `.gitignore` so copied binaries are not committed, while still being included in the APK via the normal Android assets merge.

#### Scenario: Clean clone requires build to populate firmware assets

- **WHEN** a developer clones the repository without firmware assets under `app/src/main/assets/firmware/`
- **THEN** running the documented build command SHALL copy from `firmware/` when a valid bin exists

### Requirement: Firmware assets share source of truth with make pack

The repository-root `firmware/` directory SHALL remain the canonical source for both APK-bundled firmware and `make pack` zip contents; release processes SHALL NOT maintain divergent bin copies outside that directory.

#### Scenario: Pack and APK use same bin file

- **WHEN** `firmware/LSW01H1000S1013.bin` is the sole bundled candidate
- **THEN** `make pack` and the APK assets SHALL reference the same file bytes from `firmware/`
