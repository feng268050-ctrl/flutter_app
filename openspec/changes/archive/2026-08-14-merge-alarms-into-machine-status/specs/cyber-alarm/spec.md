## MODIFIED Requirements

### Requirement: Warn alarm orchestration lives in cyber_alarm

The product stack SHALL place warn/alarm **domain policy and orchestration** in `packages/cyber_alarm`, including alarm-code catalog model, episode lifecycle, presentation ports, and historical log repository ports. Product Apps SHALL wire adapters (e.g. Modbus), implement presentation/host and storage ports, and seed product catalog/locale data. Modal warn **frost chrome** (shell, dialog body, metrics, icons) SHALL come from `packages/cyber_alarm_ui`; the App presentation host SHALL compose those widgets when implementing the presentation port. `packages/cyber_hal` MUST NOT open warn dialogs, store warn episodes, or implement resist-ack / queue policy. `packages/cyber_ui` MUST NOT own episode policy. Monitor (and other) UI widgets MUST NOT implement episode policy inline; they SHALL bind to App façades backed by `cyber_alarm`.

#### Scenario: HAL does not present warn UI

- **WHEN** an `alarm.*` attribute becomes true
- **THEN** HAL emits attribute/health watch updates only
- **AND** any modal warn dialog is shown by the App presentation host driven by `cyber_alarm`, not by HAL

#### Scenario: Monitor does not own episode policy

- **WHEN** Machine Status Device Health displays status lights or Alarm Logs rows
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

### Requirement: Historical alarm log via repository port

`cyber_alarm` SHALL define a historical alarm-log repository port. The product App SHALL implement persistence. Rows SHALL be inserted on rising-edge onset (at least code, label/title, timestamp). Clearing the historical log SHALL remove persisted history and MUST NOT clear live Modbus attribute state or force-inactive HAL values. Query APIs SHALL be consumable by Monitor without re-parsing registers.

This product App SHALL back the port with SQLite at `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`), sole table `alarm_logs` with columns `id`, `code`, `content`, `timestamp` (epoch ms), `level`. Display SHALL format `timestamp` as `YYYY-MM-DD HH:mm` (local). The repository SHALL insert one row per `insertRising` call and MUST NOT apply a time-window dedup; onset policy belongs to Modbus health / attribute edges and `cyber_alarm` (rising only). The App MUST NOT use a JSON-array file as the primary alarm history store.

#### Scenario: Rising edge inserts history

- **WHEN** alarm code `H001` transitions inactive→active
- **THEN** a history row for `H001` is persisted

#### Scenario: Clear history only

- **WHEN** the operator clears Alarm Logs on Machine Status
- **THEN** historical rows are removed
- **AND** if `alarm.gun_comm` remains true, Device Health MAY still show that communication fault and the App warn host MAY still show the live episode

#### Scenario: No repository time-window dedup

- **WHEN** the coordinator calls `insertRising` twice for the same code
- **THEN** the repository persists two rows (callers MUST NOT rely on store-side coalescing)

### Requirement: Status lights remain separate from warn episodes

Machine Status Device Health Cyber status lights (Success Icon / Failure Icon / Idle) SHALL continue to reflect attribute health semantics only. Machine Status Live Status run tiles SHALL continue Dot Success/Idle run semantics. Neither light path SHALL replace or implement warn episode presentation.

#### Scenario: Failure light without owning dialog

- **WHEN** `alarm.gun_comm` is true and controller status is ready
- **THEN** the Gun Comm Status light shows Failure (red cross) per Device Health rules
- **AND** any modal warn is owned by the App warn presentation host backed by `cyber_alarm`, not by the status indicator widget
