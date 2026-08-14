# cyber-alarm Specification

## Purpose
Shared warn/alarm domain package (`packages/cyber_alarm`): catalog model, episode lifecycle, presentation/log ports; Apps wire adapters and hosts. HAL stays attribute/health only.

## Requirements
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

### Requirement: Multiple alarm signal sources merge into one coordinator

`cyber_alarm` SHALL continue to consume alarm activity through a single inbound `AlarmSignalSource` port on the coordinator. Product Apps MUST be able to merge multiple transport adapters (at least the existing Modbus attribute adapter and an IP-camera health adapter for C002) into that port without changing episode lifecycle, queueing, or recover/ack policy inside the package. Package episode policy MUST remain transport-agnostic (stable codes + active/inactive + kind only).

#### Scenario: Camera and Modbus share one coordinator

- **WHEN** the App wires both a Modbus adapter and a camera health adapter into the warn stack
- **THEN** both feeds SHALL produce `AlarmSignalEvent`s consumed by one `WarnAlarmCoordinator`
- **AND** concurrent codes SHALL queue presentation under the same single-host rules

#### Scenario: Adding camera source does not fork episode policy

- **WHEN** C002 rises from camera health while a Modbus code is already showing
- **THEN** C002 SHALL enqueue behind the showing episode per existing package policy
- **AND** the App MUST NOT open a second independent warn modal host for C002

### Requirement: Catalog model in package; product seeds copy

`cyber_alarm` SHALL provide an alarm-code catalog model that defines at least code, severity, and localized title/body keys for warn presentation. The product App SHALL seed/load catalog entries for codes in scope and SHALL resolve title/body through App `AppLocalizations` (or equivalent gen-l10n accessors) for the active UI locale. Product alarm EN/ZH copy for codes in scope SHALL be seeded from lws-ui alarm string resources when a match exists. HAL `meta.label` / `meta.alarm_code` MAY supply join keys and list labels but MUST NOT be the sole source of dialog severity policy or bilingual dialog copy.

#### Scenario: Catalog drives dialog content

- **WHEN** a warn episode for code `H001` is presented
- **THEN** dialog title and body SHALL come from the product catalog resolved through App localization keyed by that catalog
- **AND** missing catalog entries MUST soft-fail (diagnosable placeholder) without crashing the App

#### Scenario: Chinese locale shows Chinese alarm copy

- **WHEN** UI locale is `zh-CN` and a catalogued warn dialog is shown
- **THEN** title and body render Simplified Chinese strings from App localization (lws-ui-sourced when available)

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

### Requirement: Warn presentation gated during boot self-check

While product boot self-check is active, the `cyber_alarm` coordinator MUST NOT call the presentation port to show new modal warn dialogs for Modbus-backed **or non-Modbus** alarm codes (gate supplied by App). Historical insert MAY still occur per existing package policy. After self-check completes, subsequent rising edges SHALL present normally via the App **global prompt queue**, and `flushPresentation` MAY enqueue parked eligible episodes onto that queue. Warn presentation MUST NOT be held for Home guidance / network / cloud enrollment after self-check.

The coordinator MUST NOT maintain a separate modal presentation FIFO for dialogs; serialization of visible prompts SHALL be owned by the App global prompt queue. A non-UI pending set for gate-parked codes MAY remain.

#### Scenario: Suppressed during self-check

- **WHEN** boot self-check overlay is active
- **AND** an alarm attribute becomes true
- **THEN** no modal warn dialog is shown for that onset
- **AND** after self-check ends, a later new rising edge or flush MAY show a dialog via the global prompt queue without waiting for guidance enrollment

#### Scenario: Camera C002 uses the same gate

- **WHEN** boot self-check presentation is gated
- **AND** camera health reports unhealthy
- **THEN** no C002 modal SHALL be shown via the presentation port
- **AND** gating SHALL use the same App `WarnGate` as Modbus-backed codes

#### Scenario: No second warn modal queue

- **WHEN** multiple alarm codes become eligible for presentation after the gate opens
- **THEN** their dialogs SHALL be ordered by the App global prompt queue
- **AND** the coordinator MUST NOT run a parallel `_showQueue` modal drain

### Requirement: Status lights remain separate from warn episodes

Machine Status Device Health Cyber status lights (Success Icon / Failure Icon / Idle) SHALL continue to reflect attribute health semantics only. Machine Status Live Status run tiles SHALL continue Dot Success/Idle run semantics. Neither light path SHALL replace or implement warn episode presentation.

#### Scenario: Failure light without owning dialog

- **WHEN** `alarm.gun_comm` is true and controller status is ready
- **THEN** the Gun Comm Status light shows Failure (red cross) per Device Health rules
- **AND** any modal warn is owned by the App warn presentation host backed by `cyber_alarm`, not by the status indicator widget

### Requirement: Package dependency boundaries

`packages/cyber_alarm` domain and coordinator libraries MUST NOT depend on `package:cyber_hal`, `package:flutter`, or `package:cyber_alarm_ui` for episode policy. Modbus transport adapters SHALL live in the product App (or optional App-facing glue), not inside HAL. CyberUI-backed warn frost chrome SHALL live in `packages/cyber_alarm_ui`; the App SHALL implement the presentation host that enqueues onto the global prompt queue and composes those widgets.

#### Scenario: Domain stays portable

- **WHEN** package unit tests for the coordinator run on host
- **THEN** they SHALL execute without a Flutter test binding requirement for core episode logic
- **AND** without importing `cyber_hal` or `cyber_alarm_ui`

### Requirement: Product adapters may filter alarm signal edges

`cyber_alarm` SHALL continue to treat the inbound `AlarmSignalSource` as the sole source of rising/falling/reminder edges for episode policy. Product Apps MAY filter, delay, or rewrite transport-level observations into those edges before they reach `WarnAlarmCoordinator` when product policy requires it (for example suppressing false communication faults while machine e-stop is active). The package MUST NOT hard-code product e-stop attribute ids or product-specific suppress code lists. Episode lifecycle, queueing, historical insert-on-rising, and presentation gating inside the package MUST remain based only on the edges they receive.

#### Scenario: Filtered rising never arms an episode

- **WHEN** a product Modbus adapter drops or rewrites an attribute-true observation so no rising `AlarmSignalEvent` is delivered for that code
- **THEN** the coordinator MUST NOT arm an episode, MUST NOT call presentation show for that onset, and MUST NOT insert a rising history row for that onset

#### Scenario: Package stays product-agnostic

- **WHEN** unit tests exercise `WarnAlarmCoordinator` with synthetic signal events
- **THEN** those tests SHALL not require machine e-stop or laser/wire-feeder attribute ids
- **AND** product suppress policy SHALL live in the App adapter layer
