## MODIFIED Requirements

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
