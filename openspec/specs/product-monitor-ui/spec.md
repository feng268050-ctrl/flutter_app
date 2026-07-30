# product-monitor-ui Specification

## Purpose
Product Monitor screen: Machine Status (live gauges/tiles), Alarm Information temperatures and active alarms via HAL attribute ids, historical Alarm Logs (CyberUI chrome), and local process Videos list/detail (no upload in this capability slice).
## Requirements
### Requirement: Monitor Machine Status shows live Modbus and camera state

The Monitor → Machine Status tab SHALL present dual gauges and seven run tiles aligned with lws-ui `fragment_machine_status`:

| UI | Source | Notes |
|----|--------|--------|
| Gas Pressure | `telemetry.blow_pressure` | Gauge range **0–1500** kPa (lws-ui `setBlowAirPressure` max) |
| Laser Current | `telemetry.laser_current` | Decoded amps (config scale 0.1); gauge range **0–100** A |
| Laser / Blow / Safety Lock / Gun Switch / Red Light / Wire Feeding | `machine.laser_on`, `machine.air_valve_on`, `machine.safety_ground_lock`, `machine.gun_switch_on`, `machine.red_light_on`, `machine.wire_feeding_on` | Dot Success when true; Idle when false/unknown |
| Camera | product `IpCameraProductSession` | Dot Success when UI phase is connected; not a Modbus bit |

Values SHALL update via `ModbusHal.watchAttributes` (and camera status stream). The tab MUST NOT hard-code numeric Modbus addresses in the widget tree. Missing or not-yet-primed tiles SHALL remain Idle (not Success).

#### Scenario: Machine Status gauges use lws-ui ranges

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** the gas-pressure gauge max is 1500 kPa and the laser-current gauge max is 100 A

#### Scenario: Machine Status tiles follow attribute watches

- **WHEN** `machine.laser_on` becomes true while Machine Status is subscribed
- **THEN** the Laser tile Dot shows Success

### Requirement: Monitor route presents Alarm Information temperatures

The product Monitor screen SHALL present four welding-gun temperature rows aligned with lws-ui Monitor → Alarm Information: Motor, Motor Driver, Protective Mirror, and Collimator. Values SHALL come from HAL attribute ids `telemetry.gun_motor_temp`, `telemetry.gun_motor_drive_temp`, `telemetry.protective_cover_temp`, and `telemetry.collimator_temp` (decoded °C per product modbus config). Missing or failed values SHALL display `-`. The screen MUST NOT block first paint on Modbus I/O completing.

#### Scenario: Four temperature rows visible

- **WHEN** the user opens the Monitor route after assets load
- **THEN** four labeled temperature rows for Motor, Motor Driver, Protective Mirror, and Collimator are visible

#### Scenario: Soft-fail without Modbus slave

- **WHEN** Modbus reads fail or no slave is present
- **THEN** temperature rows show `-` (or equivalent placeholder) and the Monitor screen remains usable without crashing

### Requirement: Monitor presents active alarms from HAL attributes

The Monitor screen SHALL list active alarms from the product warn/alarm façade backed by `cyber_alarm` episodes. That list SHALL include:

1. Modbus-backed codes derived from product `alarm.*` boolean attributes that carry `meta.alarm_code` (via the Modbus `AlarmSignalSource` adapter), and
2. Non-Modbus codes that share the same coordinator (at least camera communication **C002** when IP-camera health is unhealthy).

An alarm SHALL appear when its episode fault is active, showing at least the alarm code and label (catalog or attribute meta). Live Modbus updates MUST use `ModbusHal.watchAttributes` (or AppServices equivalent) and MUST NOT run a Dart `Timer` that loops `readAttribute` for continuous status/data groups. Camera C002 MUST NOT require a Modbus attribute bit.

#### Scenario: Active alarm appears in list

- **WHEN** an `alarm.*` attribute with an alarm code becomes true while Monitor is subscribed
- **THEN** the Monitor alarm list shows that alarm’s code and label

#### Scenario: Cleared alarm leaves list

- **WHEN** a previously true alarm attribute becomes false
- **THEN** that alarm is no longer shown as active in the list

#### Scenario: App does not poll Modbus itself

- **WHEN** Monitor needs live temperatures and alarms
- **THEN** it subscribes via HAL watch APIs and does not start a Timer-based `readAttribute` poll loop for those continuous groups

#### Scenario: Camera C002 appears without Modbus bit

- **WHEN** IP-camera health is unhealthy and a C002 episode is active
- **THEN** the Monitor active-alarm list SHALL show code **C002** with the catalog label
- **AND** MUST NOT require a Modbus `alarm.*` attribute for that row

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

The product App SHALL persist history in SQLite under `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`), sole table `alarm_logs` with columns `code`, `content`, `timestamp` (epoch ms), `level`. UI SHALL format `timestamp` as `YYYY-MM-DD HH:mm`. Each rising-edge `insertRising` SHALL append a row; the store MUST NOT coalesce by code/time (onset policy is Modbus + `cyber_alarm`). Startup MAY prune rows older than **90 days**.

#### Scenario: History visible on Monitor

- **WHEN** at least one historical row exists and the operator opens Alarm Information
- **THEN** Alarm Logs shows that row’s code and time (and label when available)

#### Scenario: Clear removes history UI

- **WHEN** the operator activates Clear on Alarm Logs
- **THEN** historical rows disappear from the Logs list
- **AND** the App MUST NOT claim “coming soon”

#### Scenario: Persist path is alarm-logs.db

- **WHEN** a rising-edge warn is logged on device
- **THEN** a row is written to `alarm_logs` in `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`; not a JSON array file)

### Requirement: Monitor remains a consumer of warn APIs

Monitor Alarm Information SHALL subscribe to HAL (or App façades) for lights/temps/active bits as today, and SHALL consume historical log streams/APIs from the App façade over `cyber_alarm`. Monitor MUST NOT implement warn episode policy or open a second warn dialog stack local to the tab.

#### Scenario: No tab-local episode controller

- **WHEN** Alarm Information is open and a Modbus alarm rises
- **THEN** modal warn presentation is performed by the App-wide presentation host backed by `cyber_alarm`
- **AND** the Alarm Information tab does not create a parallel episode state machine

### Requirement: Monitor shell uses the CyberUI page status bar

The Monitor screen shell SHALL use the CyberUI **page status bar** (leading back, centered title, trailing extensible `CyberHomeStatusBar` + compact clock) rather than a bare back-and-title AppBar or an App-local status-bar fork. For this product’s current icon set the trailing bar SHALL include Wi‑Fi · Bluetooth · camera. Monitor tab content and `AppBar.bottom` tab strip behavior remain as specified elsewhere in this capability; the page status bar applies to the top chrome row only.

#### Scenario: Monitor top chrome includes status and clock

- **WHEN** the operator opens Monitor
- **THEN** the Monitor top chrome is the CyberUI page status bar showing back, the Monitor title, this product’s current status icons, and a compact clock
- **AND** Monitor tabs remain available beneath that chrome as today

### Requirement: Monitor chrome and labels use App localization

Monitor shell title, tab labels, and migrated operator-visible row/tile labels SHALL use `AppLocalizations` for the active UI locale. Alarm Information list labels for catalogued codes SHALL follow the same localization resolution as warn presentation (`cyber-alarm` / App catalog keys).

#### Scenario: Monitor title follows locale

- **WHEN** Language is `zh-CN` and the operator opens Monitor
- **THEN** the Monitor page status-bar title and migrated tab labels render in Simplified Chinese

#### Scenario: Machine Status labels follow locale

- **WHEN** Language is `zh-CN` and the operator opens Machine Status
- **THEN** migrated gauge and run-tile labels render in Simplified Chinese via App localization

### Requirement: Monitor Videos tab lists local process recordings

Monitor → Videos SHALL present a table aligned with lws-ui `fragment_process_video` columns: Recording Time, Work Mode, Material, Duration, and Operations. Rows SHALL come from the process-video repository (newest first), not from a directory scan alone. An empty library SHALL show a clear empty state (no crash). Upload actions MUST NOT be offered in this change.

#### Scenario: Populated list shows core columns

- **WHEN** at least one process-video row exists and the operator opens Monitor → Videos
- **THEN** each visible row shows recording time, work mode label, material label (or placeholder), duration, and a Delete control
- **AND** MUST NOT show an active Upload control

#### Scenario: Empty state

- **WHEN** the process-video library is empty
- **THEN** Videos tab shows an empty-state message instead of a stuck loading spinner

#### Scenario: Refresh after new recording

- **WHEN** the operator returns to Videos after a new Record Work save
- **THEN** the new row is visible without requiring an App reinstall (pull-to-refresh or reopen/reload is acceptable)

### Requirement: Videos row opens local detail with playback and parameters

Tapping a Videos row (outside Delete) SHALL open a detail view for that recording. Detail SHALL play the local MP4 when the file is valid, show a parameter panel driven by `process_parameters_json` (with process type / material fallbacks), and provide Back plus Delete. Detail MUST NOT require cloud URLs or upload.

#### Scenario: Local playback

- **WHEN** the operator opens detail for a row whose `video_path` exists and is playable
- **THEN** the detail view presents transport controls and plays the local file

#### Scenario: Parameter panel

- **WHEN** detail opens for a row with a process parameter snapshot
- **THEN** the parameter panel shows at least functional mode and material (when applicable)
- **AND** mode-relevant numeric parameters from the snapshot are visible according to process type

#### Scenario: Missing file soft-fails

- **WHEN** detail opens but the MP4 is missing or unreadable
- **THEN** the UI shows an error/placeholder and remains dismissible without crashing

### Requirement: Monitor Videos supports local delete with confirmation

From the Videos list or detail, Delete SHALL ask for confirmation, then remove the index row and best-effort delete the file, and refresh the list (or pop detail with a result that refreshes).

#### Scenario: Confirm delete from list

- **WHEN** the operator confirms Delete on a list row
- **THEN** that row disappears from Videos
- **AND** the corresponding process-video repository entry is gone

#### Scenario: Cancel delete

- **WHEN** the operator cancels the delete confirmation
- **THEN** the row and file remain unchanged
