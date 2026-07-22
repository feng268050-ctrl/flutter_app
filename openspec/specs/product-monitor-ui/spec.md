# product-monitor-ui Specification

## Purpose
Product Monitor screen: Alarm Information temperatures and active alarms via HAL attribute ids (Material stand-in until CyberUI).
## Requirements
### Requirement: Monitor route presents Alarm Information temperatures

The product Monitor screen SHALL present four welding-gun temperature rows aligned with lws-ui Monitor → Alarm Information: Motor, Motor Driver, Protective Mirror, and Collimator. Values SHALL come from HAL attribute ids `telemetry.gun_motor_temp`, `telemetry.gun_motor_drive_temp`, `telemetry.protective_cover_temp`, and `telemetry.collimator_temp` (decoded °C per product modbus config). Missing or failed values SHALL display `-`. The screen MUST NOT block first paint on Modbus I/O completing.

#### Scenario: Four temperature rows visible

- **WHEN** the user opens the Monitor route after assets load
- **THEN** four labeled temperature rows for Motor, Motor Driver, Protective Mirror, and Collimator are visible

#### Scenario: Soft-fail without Modbus slave

- **WHEN** Modbus reads fail or no slave is present
- **THEN** temperature rows show `-` (or equivalent placeholder) and the Monitor screen remains usable without crashing

### Requirement: Monitor presents active alarms from HAL attributes

The Monitor screen SHALL list active alarms derived from product `alarm.*` boolean attributes that carry `meta.alarm_code` in the modbus config. An alarm SHALL appear in the list when its decoded value is true, showing at least the alarm code and label (from attribute meta when present). The App MUST obtain live updates via `ModbusHal.watchAttributes` (or AppServices equivalent backed by it) and MUST NOT run a Dart `Timer` that loops `readAttribute` for continuous status/data groups.

#### Scenario: Active alarm appears in list

- **WHEN** an `alarm.*` attribute with an alarm code becomes true while Monitor is subscribed
- **THEN** the Monitor alarm list shows that alarm’s code and label

#### Scenario: Cleared alarm leaves list

- **WHEN** a previously true alarm attribute becomes false
- **THEN** that alarm is no longer shown as active in the list

#### Scenario: App does not poll Modbus itself

- **WHEN** Monitor needs live temperatures and alarms
- **THEN** it subscribes via HAL watch APIs and does not start a Timer-based `readAttribute` poll loop for those continuous groups

### Requirement: Monitor uses Material stand-in UI

Monitor MAY use Flutter Material for page layout and tabs. Frost / status glass chrome SHALL use CyberUI when the capability is migrated; Monitor MUST NOT require a second in-app glass kit parallel to `packages/cyber_ui`.

#### Scenario: Monitor opens with Material shell

- **WHEN** the user navigates to Monitor on the current Flutter pin
- **THEN** the Monitor screen renders with Material-based layout/tabs and remains usable

#### Scenario: Glass chrome not forked in Monitor

- **WHEN** Monitor needs frosted or Cyber status chrome after CyberUI adoption
- **THEN** it depends on `packages/cyber_ui` rather than maintaining a separate Monitor-only glass implementation

### Requirement: Monitor respects Modbus health soft-fail

Monitor MAY observe `ModbusHal.watchHealth` (or AppServices equivalent) to indicate communication problems. Health indication MUST NOT crash the UI. HAL-owned Warn dialog presentation is out of scope; a simple non-blocking banner or text is sufficient.

#### Scenario: Health fault does not crash Monitor

- **WHEN** continuous group health reports failure while Monitor is open
- **THEN** the Monitor screen remains open and continues to show last-good or `-` values without crashing

### Requirement: Monitor prefers CyberUI for status and glass chrome

Where Monitor shows Cyber status lights or frosted panels, it SHALL use CyberUI components (`CyberStatusIndicator` or successors) once `packages/cyber_ui` is adopted. Layout shells MAY remain Material.

#### Scenario: Alarm status lights use CyberUI indicator

- **WHEN** Monitor Alarm Information shows status lights after CyberUI migration
- **THEN** those lights are built from CyberUI status APIs rather than a one-off feature-local indicator fork

### Requirement: Monitor may adopt Cyber borders and controls

Monitor chrome that needs frosted panels or interactive Cyber controls SHALL prefer `packages/cyber_ui` components when available. Status indicators already using Cyber MUST remain on the package API.

#### Scenario: Status stays on CyberStatusIndicator

- **WHEN** Monitor renders machine/alarm status lights
- **THEN** they continue to use `CyberStatusIndicator` (or successor) from cyber_ui

### Requirement: Monitor Alarm Logs use historical repository

The Monitor Alarm Information “Alarm Logs” surface SHALL display App-persisted historical alarm rows from the store implementing the `cyber_alarm` alarm log repository port (not only the live true-bit list). Clear SHALL invoke that repository clear API. Live active alarms MAY still be shown as a separate live section or badge driven by attribute watches, but Clear MUST NOT be implemented as a stub snackbar once this capability lands.

#### Scenario: History visible on Monitor

- **WHEN** at least one historical row exists and the operator opens Alarm Information
- **THEN** Alarm Logs shows that row’s code and time (and label when available)

#### Scenario: Clear removes history UI

- **WHEN** the operator activates Clear on Alarm Logs
- **THEN** historical rows disappear from the Logs list
- **AND** the App MUST NOT claim “coming soon”

### Requirement: Monitor remains a consumer of warn APIs

Monitor Alarm Information SHALL subscribe to HAL (or App façades) for lights/temps/active bits as today, and SHALL consume historical log streams/APIs from the App façade over `cyber_alarm`. Monitor MUST NOT implement warn episode policy or open a second warn dialog stack local to the tab.

#### Scenario: No tab-local episode controller

- **WHEN** Alarm Information is open and a Modbus alarm rises
- **THEN** modal warn presentation is performed by the App-wide presentation host backed by `cyber_alarm`
- **AND** the Alarm Information tab does not create a parallel episode state machine
