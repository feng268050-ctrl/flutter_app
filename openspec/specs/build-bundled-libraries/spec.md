## ADDED Requirements

### Requirement: Build fetches library manifests from Workers API

The build pipeline SHALL retrieve version descriptor JSON for each bundled library artifact `ai-library` and `process-library` from `https://api-prod.lasercyber.workers.dev/view/<artifact>/<json_file>`, where `<json_file>` is `staging.json` or `release.json` as selected by Makefile or environment variable (default SHALL match the test/staging descriptor).

Each artifact’s manifest response SHALL be a JSON object that includes at minimum `version`, `filename`, `sha512`, and `url` (the same field names as the reference `staging.json` for process-library). The object MAY include `published_at`; the build SHALL NOT require `published_at` to be present or valid for packaging to proceed.

#### Scenario: Manifest includes optional published_at

- **WHEN** the manifest contains `published_at` in addition to the required fields
- **THEN** the build SHALL still succeed if all required fields are valid and download plus digest verification pass Each descriptor object SHALL include at minimum `version`, `filename`, `sha512`, and `url` (same shape as reference `staging.json`). The object MAY include `published_at`; the build SHALL NOT require `published_at` to be present or use it for download or verification.

#### Scenario: Staging manifest is used by default

- **WHEN** the build runs without selecting the production manifest flag
- **THEN** the pipeline SHALL request `staging.json` for both `ai-library` and `process-library`

#### Scenario: Release manifest is selected explicitly

- **WHEN** the build runs with the Makefile/environment configuration that selects production descriptors
- **THEN** the pipeline SHALL request `release.json` for both `ai-library` and `process-library`

### Requirement: Build downloads process-library assets into assets by suffix branch

For each artifact, the build SHALL download the file at the `url` field from the manifest and write outputs into `app/src/main/assets/<artifact>/`.

- For `ai-library`, the build SHALL keep the original behavior and write the downloaded binary using manifest `filename` as `assets/ai-library/<filename>`.
- For `process-library`, the build SHALL branch by manifest filename suffix:
  - `.xlsx`: download, verify SHA-512, and write as `assets/process-library/<filename>`.
  - `.zip`: download, verify SHA-512, then extract all `.xlsx` entries into `assets/process-library/`.
- Before writing/extracting process-library outputs, the build SHALL remove stale files from prior builds under `assets/process-library/`.
- Process-library extraction SHALL flatten to the target directory root and ignore non-xlsx entries.

Each manifest object SHALL include the fields `url`, `filename`, `sha512`, and `version`.

#### Scenario: Process-library zip expands to model files
- **WHEN** process-library manifest points to `工艺库_v1.0.1-beta.zip` containing `L1.xlsx` and `L1 Pro.xlsx`
- **THEN** the build SHALL place `assets/process-library/L1.xlsx` and `assets/process-library/L1 Pro.xlsx` before APK assembly

#### Scenario: Process-library xlsx keeps legacy single-file behavior
- **WHEN** process-library manifest points to `工艺库_v1.0.1-beta.xlsx`
- **THEN** the build SHALL place `assets/process-library/工艺库_v1.0.1-beta.xlsx` directly before APK assembly

#### Scenario: Build cleans stale process-library files before extraction
- **WHEN** `assets/process-library/` already contains old model xlsx files from a previous build
- **THEN** the build SHALL delete stale files before extracting the newly downloaded process-library zip

#### Scenario: Optional published_at is ignored by build

- **WHEN** the manifest includes `published_at` (ISO 8601) alongside required fields
- **THEN** the build SHALL still succeed without consuming `published_at` for download or SHA-512 verification

### Requirement: Build verifies SHA-512 before packaging

After each download completes, the build SHALL compute the SHA-512 digest of the downloaded bytes and compare it to the `sha512` value from the manifest (after normalizing encoding/case per implementation convention). On mismatch, the build SHALL fail and SHALL NOT proceed to assemble an APK with that file.

#### Scenario: Tampered or corrupted download fails the build

- **WHEN** the computed digest does not equal the manifest `sha512`
- **THEN** the build SHALL terminate with a non-success status and SHALL NOT package the corrupt artifact

### Requirement: Generated asset directories are ignored by Git

The repository SHALL list `assets/ai-library/` and `assets/process-library/` (or equivalent paths under the app module) in `.gitignore` so downloaded binaries are not committed, while still being included in the APK via the normal Android assets merge.

#### Scenario: Clean clone requires build to populate libraries

- **WHEN** a developer clones the repository without those files
- **THEN** running the documented build command SHALL recreate them before packaging

### Requirement: Startup import compares against DeviceInfo versions

At runtime, library import decisions SHALL use `t_device_info.processLibVersion` and `t_device_info.AIVersion` as the installed-version baseline. The implementation SHALL normalize asset filename-derived semver to core version (`MAJOR.MINOR.PATCH`) and compare against these fields via the shared SemVer helper.

#### Scenario: Empty DeviceInfo version means not imported

- **WHEN** `processLibVersion` or `AIVersion` is empty/null
- **THEN** the app SHALL treat that library as not yet imported and SHALL execute import from bundled assets

### Requirement: Runtime import does not retain source xlsx/zip files

Runtime import of bundled `process-library` and `ai-library` SHALL use temporary files only and SHALL delete temporary `xlsx/zip` artifacts after import completes (success or failure cleanup path per implementation constraints).

#### Scenario: No persistent source archives after import

- **WHEN** import finishes
- **THEN** app data SHALL NOT retain source `process-library` `.xlsx` or `ai-library` `.zip` as long-lived files for version comparison

#### Scenario: Update removes stale library payloads

- **WHEN** a newer bundled library is imported
- **THEN** stale library payload directories/files from prior versions SHALL be removed before writing the new payload

### Requirement: DeviceInfo stores core library versions

When library import succeeds, `t_device_info.processLibVersion` and `t_device_info.AIVersion` SHALL be persisted as core semver (`MAJOR.MINOR.PATCH`) without prerelease/build suffixes, even if bundled filenames include markers such as `-beta` or `-alpha`.

#### Scenario: Prerelease suffix is stripped for display storage

- **WHEN** bundled filename version is `1.0.0-beta`
- **THEN** persisted DeviceInfo version SHALL be `1.0.0`

### Requirement: AI unpack directory uses core version name

When importing `ai-library`, the runtime unpack destination directory under app data SHALL use the same core semver string stored in `t_device_info.AIVersion`.

#### Scenario: JNI path aligns with DeviceInfo version

- **WHEN** bundled AI filename version is `1.0.0-beta`
- **THEN** unpack directory SHALL be `.../ai-library/1.0.0/` and DeviceInfo `AIVersion` SHALL be `1.0.0`
