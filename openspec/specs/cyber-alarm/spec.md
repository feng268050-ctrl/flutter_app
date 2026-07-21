# cyber-alarm Specification

## Purpose
Shared warn/alarm domain package (`packages/cyber_alarm`): catalog model, episode lifecycle, presentation/log ports; Apps wire adapters and hosts. HAL stays attribute/health only.

## Requirements
### Requirement: Warn alarm orchestration lives in cyber_alarm

The product stack SHALL place warn/alarm **domain policy and orchestration** in `packages/cyber_alarm`, including alarm-code catalog model, episode lifecycle, presentation ports, and historical log repository ports. Product Apps SHALL wire adapters (e.g. Modbus), implement presentation/host and storage ports, and seed product catalog/locale data. `packages/cyber_hal` MUST NOT open warn dialogs, store warn episodes, or implement resist-ack / queue policy. `packages/cyber_ui` MUST NOT own episode policy. Monitor (and other) UI widgets MUST NOT implement episode policy inline; they SHALL bind to App façades backed by `cyber_alarm`.

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

### Requirement: Alarm signal ports abstract transport

`cyber_alarm` SHALL consume alarm activity through an inbound port (e.g. `AlarmSignalSource`) that delivers stable alarm codes and active/inactive transitions. A product Modbus adapter SHALL map HAL `watchAttributes` / config `meta.alarm_code` onto that port. Future non-Modbus sources MUST be able to implement the same port without changing episode policy inside the package.

#### Scenario: Modbus adapter maps attribute to code

- **WHEN** `alarm.gun_comm` becomes true and config meta supplies alarm code `H001`
- **THEN** the signal stream exposes an active transition for code `H001`
- **AND** package policy code MUST NOT hard-code Modbus register `0x0009` or bit index

#### Scenario: Reminder is not a rising-edge log insert

- **WHEN** HAL emits a `reminder` kind change for an already-active alarm attribute
- **THEN** the historical alarm log MUST NOT insert a new rising-edge row solely due to that reminder
- **AND** episode presentation MAY refresh per package policy without treating reminder as a new fault onset

### Requirement: Catalog model in package; product seeds copy

`cyber_alarm` SHALL provide an alarm-code catalog model that defines at least code, severity, and localized title/body keys for warn presentation. The product App SHALL seed/load catalog entries for codes in scope. HAL `meta.label` / `meta.alarm_code` MAY supply join keys and list labels but MUST NOT be the sole source of dialog severity policy.

#### Scenario: Catalog drives dialog content

- **WHEN** a warn episode for code `H001` is presented
- **THEN** dialog title and body SHALL come from the product catalog (or App localization keyed by that catalog)
- **AND** missing catalog entries MUST soft-fail (diagnosable placeholder) without crashing the App

### Requirement: Episode lifecycle and single presentation host

`cyber_alarm` SHALL arm a warn episode on rising edge (inactive→active) for catalogued Modbus-backed codes in scope, enqueue presentation through a process-wide presentation port, and apply a documented dismiss/recover policy (operator ack and/or clear when signal returns inactive). Concurrent episodes SHALL be queued so at most one modal warn is interactive at a time unless product policy explicitly allows stacking (default: no stacking). The App SHALL register one presentation host implementing the port.

#### Scenario: Rising edge shows dialog

- **WHEN** a watched alarm code transitions to active and warn presentation is not gated
- **THEN** the App presentation host shows a warn dialog for that code

#### Scenario: Recover may close dialog

- **WHEN** the underlying alarm signal returns inactive while a dialog for that code is showing
- **AND** package policy allows auto-dismiss on clear
- **THEN** the dialog for that episode is dismissed without requiring a second operator action

#### Scenario: Single host

- **WHEN** Monitor and Home are both mounted
- **THEN** warn dialogs SHALL still be shown by one App-registered presentation host
- **AND** pages MUST NOT each open independent competing warn modals for the same episode

### Requirement: Historical alarm log via repository port

`cyber_alarm` SHALL define a historical alarm-log repository port. The product App SHALL implement persistence. Rows SHALL be inserted on rising-edge onset (at least code, label/title, timestamp). Clearing the historical log SHALL remove persisted history and MUST NOT clear live Modbus attribute state or force-inactive HAL values. Query APIs SHALL be consumable by Monitor without re-parsing registers.

#### Scenario: Rising edge inserts history

- **WHEN** alarm code `H001` transitions inactive→active
- **THEN** a history row for `H001` is persisted

#### Scenario: Clear history only

- **WHEN** the operator clears Alarm Logs
- **THEN** historical rows are removed
- **AND** if `alarm.gun_comm` remains true, the live active representation MAY still show that alarm as active

### Requirement: Warn presentation gated during boot self-check

While product boot self-check is active, the `cyber_alarm` coordinator MUST NOT call the presentation port to show new modal warn dialogs for Modbus-backed alarms (gate supplied by App). Historical insert MAY still occur. After self-check completes, subsequent rising edges SHALL present normally.

#### Scenario: Suppressed during self-check

- **WHEN** boot self-check overlay is active
- **AND** an alarm attribute becomes true
- **THEN** no modal warn dialog is shown for that onset
- **AND** after self-check ends, a later new rising edge MAY show a dialog

### Requirement: Status lights remain separate from warn episodes

Alarm Information Cyber status lights (Success Icon / Failure Icon / Idle) SHALL continue to reflect attribute health semantics only. Machine Status run tiles SHALL continue Dot Success/Idle run semantics. Neither light path SHALL replace or implement warn episode presentation.

#### Scenario: Failure light without owning dialog

- **WHEN** `alarm.gun_comm` is true and controller status is ready
- **THEN** the Gun Comm Status light shows Failure (red cross) per Alarm Information rules
- **AND** any modal warn is owned by the App warn presentation host backed by `cyber_alarm`, not by the status indicator widget

### Requirement: Package dependency boundaries

`packages/cyber_alarm` domain and coordinator libraries MUST NOT depend on `package:cyber_hal` or `package:flutter` for episode policy. Modbus transport adapters and CyberUI hosts SHALL live in the product App (or optional App-facing glue), not inside HAL.

#### Scenario: Domain stays portable

- **WHEN** package unit tests for the coordinator run on host
- **THEN** they SHALL execute without a Flutter test binding requirement for core episode logic
- **AND** without importing `cyber_hal`
