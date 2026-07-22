## ADDED Requirements

### Requirement: Product adapters may filter alarm signal edges

`cyber_alarm` SHALL continue to treat the inbound `AlarmSignalSource` as the sole source of rising/falling/reminder edges for episode policy. Product Apps MAY filter, delay, or rewrite transport-level observations into those edges before they reach `WarnAlarmCoordinator` when product policy requires it (for example suppressing false communication faults while machine e-stop is active). The package MUST NOT hard-code product e-stop attribute ids or product-specific suppress code lists. Episode lifecycle, queueing, historical insert-on-rising, and presentation gating inside the package MUST remain based only on the edges they receive.

#### Scenario: Filtered rising never arms an episode

- **WHEN** a product Modbus adapter drops or rewrites an attribute-true observation so no rising `AlarmSignalEvent` is delivered for that code
- **THEN** the coordinator MUST NOT arm an episode, MUST NOT call presentation show for that onset, and MUST NOT insert a rising history row for that onset

#### Scenario: Package stays product-agnostic

- **WHEN** unit tests exercise `WarnAlarmCoordinator` with synthetic signal events
- **THEN** those tests SHALL not require machine e-stop or laser/wire-feeder attribute ids
- **AND** product suppress policy SHALL live in the App adapter layer
