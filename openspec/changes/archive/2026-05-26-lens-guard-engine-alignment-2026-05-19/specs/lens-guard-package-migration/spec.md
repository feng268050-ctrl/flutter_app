## MODIFIED Requirements

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
