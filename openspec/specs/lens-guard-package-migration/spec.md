## Purpose

Define the package namespace contract for Lens Guard Java integration code after migration from the deprecated `com.lasercyber.lws.ui.lensinspector` path to `com.lasercyber.lws.ai`.
## Requirements
### Requirement: Lens Guard native bridge package SHALL be com.lasercyber.lws.ai

The system SHALL use `com.lasercyber.lws.ai` for all active Lens Guard native bridge and manager types in application integration code and authoritative integration documents. The legacy package `com.lasercyber.lws.ui.lensinspector` SHALL NOT be presented as a valid active package path.

#### Scenario: Application import path migration

- **WHEN** the Lens Guard integration code imports the native bridge or managers
- **THEN** the import path SHALL use `com.lasercyber.lws.ai`
- **AND** no active import in app source SHALL reference `com.lasercyber.lws.ui.lensinspector`

#### Scenario: Documentation contract migration

- **WHEN** integration and architecture documents describe engine package paths
- **THEN** they SHALL document `com.lasercyber.lws.ai` as the required package path
- **AND** they SHALL not present `com.lasercyber.lws.ui.lensinspector` as a valid active package contract

### Requirement: Package migration SHALL preserve callback semantics

The package namespace migration SHALL preserve Lens Guard runtime event delivery for supported runtime environments. Callback registration and EventBus publication for `onStateChanged`, `onCheckResult`, and `onAlert` SHALL remain structurally unchanged.

When the deployed engine configuration disables classification (`models.cls.enabled: false`), absence of `onStateChanged(1)` (MONITORING) and invalid `getLastClsResult` snapshots SHALL be treated as expected capability behavior, not as a breaking change to callback wiring.

#### Scenario: Callback continuity with cls enabled

- **WHEN** `models.cls.enabled` is `true` and laser transitions cause native `onStateChanged`
- **THEN** the app SHALL continue publishing `LensGuardStateEvent` with the same state integer semantics (0=IDLE, 1=MONITORING, 2=LOCKED)

#### Scenario: Det-only does not imply callback regression

- **WHEN** `models.cls.enabled` is `false` and laser is ON
- **THEN** `onCheckResult` and `onAlert` SHALL still be delivered for stain detection when applicable
- **AND** lack of MONITORING state events SHALL NOT be interpreted as failure of the callback integration layer

### Requirement: Migration completion verification SHALL scan legacy references

The migration process SHALL include explicit verification that deprecated package references are removed from active integration surfaces.

#### Scenario: Legacy reference scan

- **WHEN** migration changes are prepared for implementation completion
- **THEN** a repository scan SHALL be performed for deprecated package string `com.lasercyber.lws.ui.lensinspector` in app source and for any recommended integration path that is not `com.lasercyber.lws.ai`
- **AND** any remaining match in app source or as a recommended integration path in current guides SHALL be resolved before marking migration complete

