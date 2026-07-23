## ADDED Requirements

### Requirement: Startup SHALL choose process-library xlsx by normalized device model
At startup, when process-library import is required by version comparison, the system SHALL select the source xlsx from `assets/process-library/` by matching the normalized device model to an xlsx filename.

Device model normalization SHALL:
- remove the `LaserCyber` prefix case-insensitively when present,
- trim leading/trailing whitespace,
- collapse internal consecutive whitespace to a single space.

Filename matching SHALL be case-insensitive against `<normalized-model>.xlsx`.

When there is only one xlsx source file, the system SHALL bypass model matching and import that file directly.

#### Scenario: Exact model match after prefix stripping
- **WHEN** device model is `LaserCyber L1 Pro` and `assets/process-library/` contains `L1 Pro.xlsx`
- **THEN** the importer SHALL choose `L1 Pro.xlsx` as the process-library source

#### Scenario: Case/whitespace tolerant matching
- **WHEN** normalized device model is `L1 Pro` and assets contain `l1   pro.xlsx`
- **THEN** the importer SHALL treat the file as a valid match and import from it

#### Scenario: Single-file source bypasses model matching
- **WHEN** `assets/process-library/` contains exactly one xlsx source file
- **THEN** the importer SHALL use that file directly without requiring model-name match

### Requirement: Startup SHALL provide deterministic fallback when model file is missing
If no xlsx matches the normalized device model, the system SHALL select a deterministic fallback xlsx from `assets/process-library/` (stable sorted first entry), continue import, and emit a warning log containing device model, normalized model, and chosen fallback filename.

#### Scenario: Missing model-specific file falls back with diagnostics
- **WHEN** normalized model `L1 Pro` has no corresponding xlsx and directory contains `L1.xlsx` and `L2.xlsx`
- **THEN** the importer SHALL use the stable first file as fallback and SHALL log the fallback decision
