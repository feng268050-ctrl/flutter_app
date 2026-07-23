## ADDED Requirements

### Requirement: App SHALL expose a Lens Guard capability profile after engine start

After `LensGuardManager` successfully creates and starts a native session, the system SHALL build and expose a read-only `LensGuardCapabilityProfile` (or equivalent) that aggregates engine capabilities relevant to UI and workflow branching.

The profile SHALL include at least:

- `classificationEnabled` — derived from deployed `config.yaml` key `models.cls.enabled` (default `false` if missing or unreadable).
- `detectionEnabled` — derived from `models.det.enabled` (default `true` if missing).
- `offlineInferJsonAvailable` — derived from runtime verification that `nativeInferImageToJson` can be invoked without `UnsatisfiedLinkError` for the active session.
- `focusMonitoringExpected` — `true` only when `classificationEnabled` is `true` and the native session is running.

#### Scenario: Det-only config on device

- **WHEN** deployed `config.yaml` has `models.cls.enabled: false` and `models.det.enabled: true`
- **THEN** `classificationEnabled` SHALL be `false`
- **AND** `detectionEnabled` SHALL be `true`
- **AND** `focusMonitoringExpected` SHALL be `false`

#### Scenario: Classification re-enabled in config after session restart

- **WHEN** `models.cls.enabled` is changed to `true` on disk and the native session is destroyed and recreated
- **THEN** the profile SHALL be rebuilt with `classificationEnabled: true`
- **AND** `focusMonitoringExpected` SHALL be `true` while the session is running

### Requirement: Capability profile SHALL be the preferred gate for cls and MONITORING expectations

Application code that branches on whether classification or laser MONITORING is expected SHALL consult the capability profile (or methods delegated from `LensGuardManager`) rather than hard-coded assumptions that cls is always enabled.

#### Scenario: UI checks before showing MONITORING label

- **WHEN** laser turns ON and `focusMonitoringExpected` is `false`
- **THEN** AI Vision overlay state text SHALL NOT wait indefinitely for `onStateChanged(1)`
- **AND** SHALL NOT treat absence of MONITORING as a streaming failure

### Requirement: Profile construction failures SHALL degrade safely

If `config.yaml` cannot be read or parsed, the system SHALL log a warning and apply engine-aligned defaults (`classificationEnabled=false`, `detectionEnabled=true`) rather than crashing startup.

#### Scenario: Missing config file

- **WHEN** the lens guard config path does not exist at profile build time
- **THEN** the profile SHALL use the defaults above
- **AND** Lens Guard engine startup SHALL continue if native create otherwise succeeds
