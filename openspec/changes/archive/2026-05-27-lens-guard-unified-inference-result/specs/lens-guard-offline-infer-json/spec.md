## ADDED Requirements

### Requirement: Offline timeline prefers inferFromJpg

AI Vision process-video and offline analysis boundaries SHALL use `LensGuardManager.inferFromJpg` returning `LensGuardInferenceResult` as the primary API. Raw `inferJpgToJson` strings MUST NOT cross feature module boundaries except inside deprecated compatibility shims.

#### Scenario: Session timeline population

- **WHEN** `ProcessVideoAiSession` records a sample
- **THEN** it MUST call `inferFromJpg`
- **AND** MUST NOT require `onCheckResult` for that sample

#### Scenario: Deprecated string API

- **WHEN** legacy code calls `inferJpgToJson`
- **THEN** the implementation MAY wrap `inferFromJpg` and serialize to JSON for backward compatibility
