# hal-modbus-config Specification

## Purpose
TBD - created by archiving change dart-hal-package. Update Purpose after archive.
## Requirements
### Requirement: Modbus config schema
`hal/modbus` SHALL load a versioned config document (JSON preferred) that declares at least: `version`, `transport` (RTU device path, baud, framing, `unit_id`, timeout), and an `attributes[]` catalog. Config SHALL support a `groups` object describing contiguous register segments and a `poll` object for scheduler defaults. Each attribute SHALL have a stable string `id`, `access` (`r` / `w` / `rw`), a `register` binding (`space`, `address`, `count`), and a `decode` description. Attributes MAY reference a `group` id. The config MAY include a top-level `capabilities` object (e.g. which function codes / spaces are allowed).

#### Scenario: Transport for product welder link
- **WHEN** loading the product App’s modbus config (e.g. `assets/hal/modbus.json`)
- **THEN** transport SHALL open the product UART (e.g. `/dev/ttyS5` at the product baud) via the package RTU transport (Posix or documented equivalent)

#### Scenario: Poll interval from config
- **WHEN** `poll.interval_ms` is omitted
- **THEN** HAL SHALL default to **100** milliseconds
- **WHEN** `poll.interval_ms` is set to another positive value
- **THEN** continuous group polling SHALL use that interval

### Requirement: Poll groups and contiguous reads
Continuous telemetry SHALL be expressed as named `groups` with `space`, `start`, `count`, and `mode` (`continuous` | `on_demand`). HAL SHALL read each continuous group as **one contiguous register read** (not one Modbus frame per attribute). Groups MAY declare `chain` to another group id (e.g. status → data). Transport SHALL honor `command_interval_ms` (default **50**) between commands. When `poll.discard_if_busy` is true (default), a poll tick SHALL be discarded if a cycle or other command is in flight or an exclusive session is active. `startPolling` on a given HAL instance SHALL be **idempotent while already polling**: a second call MUST NOT stop/restart the scheduler or change the active group set; after `stopPolling`, `startPolling` MAY start again (e.g. exclusive-session resume).

#### Scenario: Status then data cycle
- **WHEN** ynh960-style config defines continuous `status` chained to `data` and polling is started
- **THEN** HAL SHALL attempt a status contiguous read then a data contiguous read within a cycle, spaced by the command interval, at the configured poll interval

#### Scenario: Second startPolling while live is ignored
- **WHEN** continuous polling is already active on a Modbus HAL instance
- **AND** the App calls `startPolling` again (with or without `groupIds`)
- **THEN** HAL SHALL leave the existing poll timer and group set unchanged

#### Scenario: On-demand info group
- **WHEN** an `info` group has `mode: on_demand`
- **THEN** it SHALL NOT be included in the default continuous poll and SHALL be readable via `readGroup` / attribute reads that target that group

### Requirement: Attribute API over raw addresses
Product Apps SHALL read/write logical attributes by `id`. HAL SHALL translate attribute ids to register operations and decode/encode values. An optional raw register API MAY exist for engineering/debug only and MUST NOT be required for Demo product paths after cutover.

#### Scenario: Control card version attribute
- **WHEN** the App calls `readAttribute("device.control_card_version")` with a config that maps that id to the correct space/address
- **THEN** HAL SHALL perform the corresponding Modbus read and return a decoded value without the App supplying the address

#### Scenario: Unknown attribute id
- **WHEN** the App requests an attribute id absent from config
- **THEN** HAL SHALL return a structured not-found error and MUST NOT invent a register address

### Requirement: Alarm bitfields as human-readable attributes
Status alarm and machine bits SHALL be mapped in config to **stable, human-readable attribute ids** (e.g. `alarm.gun_comm`) using bit decode (`decode.type` of `bit` / equivalent with bit index and active level). HAL SHALL expose decoded **boolean** (or small enum) values for those attributes. Product Apps MUST NOT parse raw register bitmasks as the long-term pattern after cutover. Optional `meta.label` / `meta.alarm_code` MAY annotate attributes; dialog copy and episode policy remain in the App.

#### Scenario: Gun communication bit
- **WHEN** config maps `alarm.gun_comm` to input `0x0009` bit 0 active-high and that bit is set in a successful status read
- **THEN** `readAttribute` / watch payloads for `alarm.gun_comm` SHALL be true (or equivalent active value), not the full register word

### Requirement: HAL-owned watch with change-only attribute callbacks
`hal/modbus` SHALL provide subscription APIs (e.g. `watchAttributes`) driven by the HAL poll scheduler. Product Apps MUST NOT implement their own Modbus poll timers for capabilities covered by continuous groups. Each watch emission SHALL be a **list of attribute changes** that includes **only attributes whose decoded values changed** since the previous emission (or since subscribe prime), and MAY also include **timed reminder** entries for attributes that remain active under the configured remind policy. Reminder entries SHALL be distinguishable (e.g. `kind: reminder`) so Apps can avoid treating them as rising-edge log inserts. Empty lists MUST NOT be emitted. Multiple attributes in one cycle MAY be delivered in a **single** list callback.

#### Scenario: Temperature changes, alarms stable
- **WHEN** continuous poll updates data registers and only `telemetry.gun_motor_temp` decoded value changed
- **THEN** the watch callback list SHALL contain that attribute (and any other actually changed ids) and MUST NOT include unchanged alarm attributes (unless a reminder is due)

#### Scenario: Alarm reminder while still active
- **WHEN** `alarm.gun_comm` stays true longer than its configured remind interval
- **THEN** HAL SHALL emit a watch item for that id marked as reminder without requiring the bool to toggle

#### Scenario: App does not poll
- **WHEN** a product Monitor screen needs live temperatures and alarms
- **THEN** it SHALL subscribe via HAL watch APIs and MUST NOT start a Dart `Timer` that calls `readAttribute` in a loop for those continuous groups

### Requirement: Read health for comm fault (C001 input)

HAL SHALL expose aggregate continuous-poll read health suitable for controller↔HMI communication faults (C001-class). Config MAY define a sliding window (`window_size`, `failure_threshold`, default 5 / 3) and mode (`slide_window` | `immediate`) under `poll.health` in the product modbus asset. HAL SHALL record group-cycle outcomes into that window and emit **aggregate** `ModbusHealth` events only (not per-group rising/falling that would bypass the window). Recovery SHALL emit `ok: true` when the window is healthy again. HAL SHALL support a runtime mode override API (`applyHealthWindowMode`) so the App can apply `properties.ini` `control_card_comm_alarm_mode` (`slide_window` | `immediate`); empty/absent `properties.ini` key keeps the asset default. On-demand `readGroup` MUST NOT drive the C001 health stream. HAL MUST NOT own Warn dialog presentation.

#### Scenario: Truncated status keeps last-good

- **WHEN** a continuous group read is truncated or fails
- **THEN** HAL SHALL retain last-good decoded attribute values for that group, record a health failure, and MUST NOT invent register values

#### Scenario: Aggregate window gates C001 input

- **WHEN** `poll.health.mode` is `slide_window` with failure_threshold 3
- **AND** continuous poll records fewer than three failures in the window
- **THEN** aggregate health SHALL remain `ok: true` (no premature per-group `ok: false` emission for C001)

#### Scenario: properties.ini mode override

- **WHEN** the App calls `applyHealthWindowMode('immediate')` after loading `control_card_comm_alarm_mode`
- **THEN** the next continuous-poll failure SHALL make aggregate health unhealthy without waiting for the slide-window threshold

### Requirement: Exclusive session and batch writes
HAL SHALL support pausing continuous poll for an exclusive bus session (OTA-class) and batch holding writes via group/attribute maps without requiring the App to manage the serial gate. Writes SHALL share the same command interval / busy discard rules as polls.

#### Scenario: Exclusive session pauses continuous poll
- **WHEN** the App opens an exclusive Modbus session (e.g. for OTA)
- **THEN** continuous group polling SHALL pause until the session is released, and batch/holding writes issued in that session SHALL still honor `command_interval_ms`

### Requirement: Register maps live in config
Numeric Modbus addresses and bit indices used by product UIs SHALL live in the **product App’s** modbus config asset (or an explicit product overlay config), not as long-lived Dart `static const` maps inside the App after cutover, and NOT as a board-named file inside `packages/cyber_hal/`. Config `version` SHALL allow golden tests against known lws-ui / Demo register sets. The same motherboard MAY use different attribute catalogs across products.

#### Scenario: Temperature map migration
- **WHEN** migrating gun-motor temperature from App constants
- **THEN** the attribute (e.g. `telemetry.gun_motor_temp` → input `0x0061`) SHALL appear in the App modbus config and App code SHALL reference the attribute id

### Requirement: Product Monitor consumes catalog attribute ids

Product Monitor UI paths for Alarm Information temperatures and boolean alarms SHALL reference stable attribute ids from the product App modbus config asset (e.g. `telemetry.gun_motor_temp`, `alarm.gun_motor_over_temp`, `alarm.gun_comm`). Those paths MUST NOT hard-code numeric Modbus addresses or bit indices in Dart UI/application code after this capability lands. Adding a missing Monitor field SHALL be done by extending the config catalog (and optionally meta), not by embedding addresses in the widget tree.

#### Scenario: Temperature rows use attribute ids

- **WHEN** Monitor displays Motor temperature
- **THEN** the application layer requests or watches `telemetry.gun_motor_temp` (or an equivalent catalog id) and MUST NOT embed `0x0061` in Monitor UI code

#### Scenario: Alarm list uses attribute ids and meta

- **WHEN** Monitor shows an active gun-communication alarm
- **THEN** it uses the `alarm.gun_comm` attribute (and config meta for code/label when present) rather than parsing a raw status register bitmask in the UI

### Requirement: Multiple watch subscribers with distinct id filters
`hal/modbus` SHALL allow multiple concurrent `watchAttributes` subscriptions on one HAL instance. Each subscription MAY supply its own `ids` filter. Emissions to a subscriber SHALL include only changes (and reminders) for attributes in that subscriber’s filter (or all changing attributes when `ids` is omitted, per existing watch semantics). Starting or canceling one subscription MUST NOT stop continuous polling or other subscribers. Product Apps that show multiple live Modbus surfaces SHOULD use per-subscriber `ids` rather than a single App-owned undifferentiating fan-out of all watched attributes.

#### Scenario: Two subscribers different ids
- **WHEN** continuous polling is active
- **AND** subscriber A watches `telemetry.gun_motor_temp` only
- **AND** subscriber B watches `alarm.gun_comm` only
- **AND** only the motor temperature decoded value changes in a cycle
- **THEN** subscriber A SHALL receive that change
- **AND** subscriber B MUST NOT receive an emission for that cycle (unless a reminder or other B-filtered change is due)

#### Scenario: Cancel one watch leaves poll and peers
- **WHEN** two watch subscriptions are active
- **AND** the App cancels one subscription
- **THEN** continuous polling SHALL continue
- **AND** the remaining subscription SHALL keep receiving filtered updates

### Requirement: HAL remains attribute and health source only for warns

HAL Modbus SHALL continue to expose decoded `alarm.*` attributes, optional `meta.alarm_code` / `meta.label`, change-only watches (including distinguishable reminder kinds), and read-health streams suitable as inputs to App / `cyber_alarm` C001-class UI. HAL MUST NOT implement warn dialog UI, episode persistence, resist-ack queues, or product alarm-code severity catalogs. Product warn presentation and historical logging remain `cyber_alarm` + App responsibilities (not HAL).

#### Scenario: Health stream without dialog

- **WHEN** continuous group health reports failure
- **THEN** HAL emits health suitable for App / `cyber_alarm` consumption
- **AND** HAL MUST NOT open a warn dialog

#### Scenario: Meta is annotation not policy owner

- **WHEN** config provides `meta.alarm_code` on `alarm.gun_comm`
- **THEN** Apps MAY join that code to a product catalog (via `cyber_alarm`) for presentation
- **AND** HAL MUST NOT require dialog copy fields in modbus config as the presentation system of record

