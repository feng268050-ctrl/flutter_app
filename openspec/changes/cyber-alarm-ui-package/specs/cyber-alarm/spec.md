## MODIFIED Requirements

### Requirement: Warn alarm orchestration lives in cyber_alarm

The product stack SHALL place warn/alarm **domain policy and orchestration** in `packages/cyber_alarm`, including alarm-code catalog model, episode lifecycle, presentation ports, and historical log repository ports. Product Apps SHALL wire adapters (e.g. Modbus), implement presentation/host and storage ports, and seed product catalog/locale data. Modal warn **frost chrome** (shell, dialog body, metrics, icons) SHALL come from `packages/cyber_alarm_ui`; the App presentation host SHALL compose those widgets when implementing the presentation port. `packages/cyber_hal` MUST NOT open warn dialogs, store warn episodes, or implement resist-ack / queue policy. `packages/cyber_ui` MUST NOT own episode policy. Monitor (and other) UI widgets MUST NOT implement episode policy inline; they SHALL bind to App façades backed by `cyber_alarm`.

#### Scenario: HAL does not present warn UI

- **WHEN** an `alarm.*` attribute becomes true
- **THEN** HAL emits attribute/health watch updates only
- **AND** any modal warn dialog is shown by the App presentation host driven by `cyber_alarm`, not by HAL

#### Scenario: Monitor does not own episode policy

- **WHEN** Alarm Information displays status lights or active alarms
- **THEN** toggling a light or list row MUST NOT itself arm or dismiss warn episodes
- **AND** episode arming SHALL occur in the `cyber_alarm` coordinator subscribed to alarm signals via App wiring

#### Scenario: Package is the shared domain layer

- **WHEN** a second product App reuses the same warn episode semantics
- **THEN** it SHALL depend on `packages/cyber_alarm` for orchestration
- **AND** MUST NOT fork a second episode state machine inside page widgets

#### Scenario: Presentation chrome comes from cyber_alarm_ui

- **WHEN** the App presentation host shows a modal warn frost dialog
- **THEN** shell/body/metrics/icons SHALL come from `packages/cyber_alarm_ui`
- **AND** episode arming and recover/ack policy SHALL remain in `cyber_alarm`

### Requirement: Package dependency boundaries

`packages/cyber_alarm` domain and coordinator libraries MUST NOT depend on `package:cyber_hal`, `package:flutter`, or `package:cyber_alarm_ui` for episode policy. Modbus transport adapters SHALL live in the product App (or optional App-facing glue), not inside HAL. CyberUI-backed warn frost chrome SHALL live in `packages/cyber_alarm_ui`; the App SHALL implement the presentation host that enqueues onto the global prompt queue and composes those widgets.

#### Scenario: Domain stays portable

- **WHEN** package unit tests for the coordinator run on host
- **THEN** they SHALL execute without a Flutter test binding requirement for core episode logic
- **AND** without importing `cyber_hal` or `cyber_alarm_ui`
