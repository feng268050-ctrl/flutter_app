## MODIFIED Requirements

### Requirement: Startup compares bundled and installed library versions
On application startup (or an equivalent early lifecycle hook that runs once per process launch before user-dependent library features), the system SHALL discover bundled library payloads for `ai-library` and `process-library` under `assets/<artifact>/` and compare bundled version against installed version using the shared SemVer helper.

- For `ai-library`, bundled version extraction continues from the bundled archive filename.
- For `process-library`, bundled version SHALL be derived from the process-library asset package filename segment:
  - when source artifact is single `.xlsx`, use that xlsx filename version segment;
  - when source artifact is `.zip`, use the zip filename version segment;
  and SHALL NOT infer package version from arbitrary extracted model filenames.
- The system SHALL normalize bundled prerelease versions to core version (`MAJOR.MINOR.PATCH`) before persisting to `DeviceInfo.processLibVersion`.

If no installed baseline exists in `DeviceInfo`, or bundled version is greater than installed version, the system SHALL execute import/update for that artifact.

#### Scenario: First install imports process-library from model xlsx set
- **WHEN** process-library bundled version metadata exists and `processLibVersion` is empty
- **THEN** startup SHALL run process-library import using model-specific xlsx selection

#### Scenario: First install imports process-library from single xlsx
- **WHEN** process-library bundled asset is a single xlsx and `processLibVersion` is empty
- **THEN** startup SHALL run process-library import directly from that xlsx

#### Scenario: Up-to-date process-library skips import
- **WHEN** bundled process-library package version is less than or equal to `DeviceInfo.processLibVersion`
- **THEN** startup SHALL NOT re-import process-library solely due to bundled assets

### Requirement: Process library import reuses pre-refactor OTA behavior
For `process-library`, the import/update logic executed after a positive version comparison SHALL continue to reuse the existing xlsx parsing and persistence behavior (file handling into existing importer, default/quick replacement semantics, and user-visible failure modes), while changing only source selection to:
1) branch by available source shape under `assets/process-library/`:
   - single xlsx: use it directly,
   - multiple xlsx: choose model-specific xlsx (with fallback),
2) pass the selected xlsx into the canonical importer.

#### Scenario: Model-specific source still yields canonical DB result
- **WHEN** startup selects `L1 Pro.xlsx` for the active device model
- **THEN** the resulting persisted process data SHALL be equivalent to invoking the legacy importer directly on `L1 Pro.xlsx`

#### Scenario: Single-file source still yields canonical DB result
- **WHEN** startup discovers only one process-library xlsx source file
- **THEN** the resulting persisted process data SHALL be equivalent to invoking the legacy importer directly on that xlsx
