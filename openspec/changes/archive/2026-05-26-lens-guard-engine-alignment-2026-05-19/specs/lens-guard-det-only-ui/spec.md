## ADDED Requirements

### Requirement: Classification overlay SHALL distinguish disabled from waiting

When `classificationEnabled` is `false` in the capability profile, the AI Vision classification presentation (for example `tvAiCls`) SHALL show an explicit «classification not enabled» state (localized) and SHALL NOT use the same copy as «waiting for classification» used when cls is enabled but snapshot is invalid.

#### Scenario: Det-only engine defaults

- **WHEN** cls is disabled in config and the user opens AI Vision live overlay
- **THEN** the classification line SHALL indicate classification is not enabled
- **AND** SHALL NOT imply a streaming or inference fault

#### Scenario: Cls enabled but no valid snapshot yet

- **WHEN** `classificationEnabled` is `true` and `LensClsSnapshotEvent` is invalid
- **THEN** the UI MAY show waiting-style copy
- **AND** periodic snapshot polling behavior MAY continue unchanged

### Requirement: Engine state overlay SHALL not require MONITORING when focus is not expected

When `focusMonitoringExpected` is `false`, the AI Vision engine state display SHALL NOT map laser ON solely to `onStateChanged(1)` / MONITORING text. Stain detection and preview detection overlays SHALL remain driven by `onCheckResult` / `preview_det` messages as today.

#### Scenario: Laser on under det-only

- **WHEN** device laser is ON and `focusMonitoringExpected` is `false`
- **THEN** `tvAiState` SHALL NOT display «monitoring» only because laser is on
- **AND** LOCKED (`state == 2`) from native SHALL still be shown when emitted

### Requirement: App SHALL not parse classification JSON from onCheckResult message

For production and preview flows, the App SHALL obtain classification display data from `getLastClsResult` / `LensClsSnapshotEvent` paths only, and SHALL NOT parse cls JSON embedded in `onCheckResult.message` (aligned with engine det-only documentation).

#### Scenario: Stain check result with det JSON in message

- **WHEN** `onCheckResult` carries `preview_det` or production stain payload in `message`
- **THEN** detection boxes SHALL be parsed from that JSON for overlay purposes
- **AND** cls fields in the same message SHALL NOT be used as the primary cls UI source
