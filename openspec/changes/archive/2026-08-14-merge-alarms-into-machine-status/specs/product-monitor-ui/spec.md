## ADDED Requirements

### Requirement: Monitor top-level navigation has four tabs

The product Monitor screen SHALL present exactly four top-level tabs, in this order: Work Info, Machine Status, Videos, AI Vision. The screen MUST NOT present a standalone Alarms / Alarm Information / Warn Info tab. Named tab indices SHALL be Work Info = 0, Machine Status = 1, Videos = 2, AI Vision = 3. Deep links that open AI Vision SHALL use the named AI Vision index (not a hardcoded former index of 4).

#### Scenario: Four tabs visible

- **WHEN** the operator opens Monitor
- **THEN** the tab strip shows Work Info, Machine Status, Videos, and AI Vision
- **AND** MUST NOT show an Alarms (or equivalent warn-info) tab

#### Scenario: AI Vision deep link uses the new index

- **WHEN** Home opens Monitor on the AI Vision tab via `MonitorRouteArgs.aiVision`
- **THEN** Monitor shows the AI Vision tab
- **AND** MUST NOT land on Videos or a missing fifth tab

### Requirement: Machine Status is a three-section single scroll

Monitor → Machine Status SHALL be one vertical page with three sections in this order: Live Status (gauges and run tiles), Device Health (communication and temperature diagnostics), Alarm Logs (historical rows). The page SHALL use a single primary scroll container (`CustomScrollView` or equivalent slivers). It MUST NOT add inner tabs on Machine Status. It MUST NOT nest a second scrollable list (inner `ListView`, inner `SettingsScrollView`, or a nested scroll view) for Device Health or Alarm Logs.

Live Status SHALL fill the first viewport of Machine Status. The four run tiles SHALL sit at the bottom of that section and MUST scroll away with Live Status (not a global sticky bar). The gauge row SHALL use remaining space above the tiles so the Gas Pressure and Laser Current cards can grow downward.

Alarm Logs SHALL pin only its section header in the same `CustomScrollView`. Historical rows SHALL continue to scroll under that header. Clear Alarm Logs SHALL be a secondary small button on the trailing side of the pinned header. The pinned header MUST be visually transparent so it blends with the Machine Status page background. It MUST keep the title, Clear control, and a 1px tab-style divider. Rows scrolling up MUST become invisible at that divider and MUST NOT paint through the header. It MUST NOT use a large opaque black plate.

#### Scenario: Three sections in one scroll

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** Live Status is visible as the first section
- **AND** scrolling the same page reveals Device Health then Alarm Logs

#### Scenario: Live Status fills the first viewport

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** Live Status occupies the first visible viewport
- **AND** Safety Clamp, Gun Switch, Red Pointer, and Camera sit at the bottom of that section
- **AND** those tiles are not pinned after Live Status scrolls off screen

#### Scenario: Alarm Logs header pins

- **WHEN** the operator scrolls Machine Status until Alarm Logs reaches the top of the page
- **THEN** the Alarm Logs header stays pinned
- **AND** historical rows continue to scroll beneath it
- **AND** Clear Alarm Logs is on the trailing side of that header

#### Scenario: No nested Machine Status tabs

- **WHEN** the operator is on Machine Status
- **THEN** there is no second tab strip for Live / Health / Logs

### Requirement: Machine Status Device Health shows communication diagnostics

Machine Status → Device Health SHALL present communication health cards for Pump (Laser Device), Gun Communication (Welding Gun, full content width), and Wire Feeder Communication. Values SHALL come from the App warn monitor façade (`WarnAlarmController.monitor` / HAL `alarm.*` attributes), not from numeric Modbus addresses in the widget tree. `null` / unprimed SHALL render Idle; fault SHALL render Failure; healthy SHALL render Success. Wire Feeder Communication MUST remain even though the Wire Feeder run tile is absent from Live Status. Device Health MUST NOT show a Camera Communication card; the Camera run tile on Live Status and C002 history / frost remain.

#### Scenario: Wire Feeder communication remains

- **WHEN** the operator opens Machine Status and scrolls to Device Health
- **THEN** a Wire Feeder Communication card is visible

#### Scenario: Camera run tile remains; Device Health has no camera comm card

- **WHEN** the operator views Machine Status
- **THEN** Live Status includes the Camera run tile
- **AND** Device Health MUST NOT show Camera Communication
- **AND** Gun Communication uses the full content width in Welding Gun

### Requirement: Machine Status has no Active Alarms section

Machine Status MUST NOT present a dedicated Active Alarms (live episode list) section. Live warn episodes SHALL continue to be presented by the App-wide `cyber_alarm` host (frost popup / sound). Device Health SHALL show communication and over-temperature health only. Historical onsets SHALL appear only under Alarm Logs.

#### Scenario: No Active Alarms heading

- **WHEN** the operator scrolls Machine Status
- **THEN** the page MUST NOT show an Active Alarms section heading or a live-episode list distinct from Alarm Logs

## MODIFIED Requirements

### Requirement: Monitor Machine Status shows live Modbus and camera state

The Monitor → Machine Status Live Status section SHALL present dual gauges and **four** run tiles:

| UI | Source | Notes |
|----|--------|--------|
| Gas Pressure | `telemetry.blow_pressure` | Gauge range **0–1500** kPa (lws-ui `setBlowAirPressure` max) |
| Laser Current | `telemetry.laser_current` | Decoded amps (config scale 0.1); gauge range **0–100** A |
| Safety Lock / Gun Switch / Red Light | `machine.safety_ground_lock`, `machine.gun_switch_on`, `machine.red_light_on` | Dot Success when true; Idle when false/unknown |
| Camera | product `IpCameraProductSession` | Dot Success when UI phase is connected; not a Modbus bit |

Live Status MUST NOT show Laser, Gas Flow (Blow), or Wire Feeder as run tiles. `MachineStatusController` MAY continue to watch `machine.laser_on`, `machine.air_valve_on`, and `machine.wire_feeding_on` for other product surfaces; removing the tiles MUST NOT delete those attributes from HAL config or stop other consumers.

Values SHALL update via `ModbusHal.watchAttributes` (and camera status stream). The tab MUST NOT hard-code numeric Modbus addresses in the widget tree. Missing or not-yet-primed tiles SHALL remain Idle (not Success). Machine Status visibility SHALL start the Live Status controller and hiding Machine Status SHALL stop it. That start/stop MUST NOT stop `WarnAlarmController`.

#### Scenario: Machine Status gauges use lws-ui ranges

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** the gas-pressure gauge max is 1500 kPa and the laser-current gauge max is 100 A

#### Scenario: Four Live Status tiles only

- **WHEN** the operator opens Monitor → Machine Status
- **THEN** Live Status shows Safety Clamp, Gun Switch, Red Pointer, and Camera run tiles
- **AND** MUST NOT show Laser, Gas Flow, or Wire Feeder run tiles

#### Scenario: Hidden bits remain available off this UI

- **WHEN** Live Status no longer shows the Laser run tile
- **THEN** `machine.laser_on` remains a valid watched attribute for other product surfaces
- **AND** Monitor Live Status MUST NOT display that tile

#### Scenario: Machine Status tiles follow attribute watches

- **WHEN** `machine.gun_switch_on` becomes true while Machine Status is subscribed
- **THEN** the Gun Switch tile Dot shows Success

### Requirement: Monitor route presents Alarm Information temperatures

The product Monitor screen SHALL present four welding-gun temperature rows on **Machine Status → Device Health** (not on a standalone Alarm Information tab): Motor, Motor Driver, Protective Mirror, and Collimator. Values SHALL come from HAL attribute ids `telemetry.gun_motor_temp`, `telemetry.gun_motor_drive_temp`, `telemetry.protective_cover_temp`, and `telemetry.collimator_temp` (decoded °C per product modbus config) via the App warn monitor façade. Missing or failed values SHALL display `-`. The screen MUST NOT block first paint on Modbus I/O completing. Live updates MUST use `ModbusHal.watchAttributes` (or AppServices equivalent) and MUST NOT run a Dart `Timer` that loops `readAttribute` for continuous status/data groups.

#### Scenario: Four temperature rows visible

- **WHEN** the user opens Monitor → Machine Status after assets load
- **THEN** four labeled temperature rows for Motor, Motor Driver, Protective Mirror, and Collimator are visible in Device Health

#### Scenario: Soft-fail without Modbus slave

- **WHEN** Modbus reads fail or no slave is present
- **THEN** temperature rows show `-` (or equivalent placeholder) and the Monitor screen remains usable without crashing

#### Scenario: App does not poll Modbus itself

- **WHEN** Machine Status Device Health needs live temperatures and communication bits
- **THEN** it subscribes via HAL watch APIs / the App warn façade and does not start a Timer-based `readAttribute` poll loop for those continuous groups

### Requirement: Monitor prefers CyberUI for status and glass chrome

Where Monitor shows Cyber status lights or frosted panels, it SHALL use CyberUI components (`CyberStatusIndicator` or successors) once `packages/cyber_ui` is adopted. Layout shells MAY remain Material.

#### Scenario: Alarm status lights use CyberUI indicator

- **WHEN** Machine Status Device Health shows status lights after CyberUI migration
- **THEN** those lights are built from CyberUI status APIs rather than a one-off feature-local indicator fork

### Requirement: Monitor Alarm Logs use historical repository

The Monitor Machine Status “Alarm Logs” surface SHALL display App-persisted historical alarm rows from the store implementing the `cyber_alarm` alarm log repository port (not only the live true-bit list). The UI SHALL subscribe with `watchHistory(limit: 200)` (or equivalent) and SHALL render at most the **latest 10** rows on this page via `latestAlarmHistoryRows()`. Clear SHALL invoke that repository clear API using the existing Clear Alarm Logs action (MUST NOT be relabeled as “Clear Alarms”). Clear MUST NOT ack live episodes, MUST NOT force-inactive HAL alarm attributes, and MUST NOT be implemented as a stub snackbar.

The product App SHALL persist history in SQLite under `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`), sole table `alarm_logs` with columns `code`, `content`, `timestamp` (epoch ms), `level`. UI SHALL format `timestamp` as `YYYY-MM-DD HH:mm`. Each rising-edge `insertRising` SHALL append a row; the store MUST NOT coalesce by code/time (onset policy is Modbus + `cyber_alarm`). Startup MAY prune rows older than **90 days**.

Camera communication **C002** SHALL appear in Alarm Logs when a rising-edge history row exists for that code and MUST NOT require a Modbus `alarm.*` attribute for that row.

#### Scenario: History visible on Machine Status

- **WHEN** at least one historical row exists and the operator opens Machine Status and views Alarm Logs
- **THEN** Alarm Logs shows that row’s code and time (and label when available)

#### Scenario: Default list is latest 10

- **WHEN** more than 10 historical rows exist
- **THEN** Machine Status Alarm Logs shows at most the 10 most recent rows

#### Scenario: Clear removes history UI

- **WHEN** the operator activates Clear Alarm Logs
- **THEN** historical rows disappear from the Logs list
- **AND** live Device Health indicators and warn frost MUST NOT be cleared solely by that action
- **AND** the App MUST NOT claim “coming soon”

#### Scenario: Persist path is alarm-logs.db

- **WHEN** a rising-edge warn is logged on device
- **THEN** a row is written to `alarm_logs` in `/var/lib/hmi/alarm-logs.db` (→ `/userdata/hmi/alarm-logs.db`; not a JSON array file)

#### Scenario: Camera C002 history without Modbus bit

- **WHEN** a C002 rising-edge history row exists from IP-camera health
- **THEN** Alarm Logs MAY show code **C002** with the catalog label
- **AND** MUST NOT require a Modbus `alarm.*` attribute for that row

### Requirement: Monitor remains a consumer of warn APIs

Machine Status Device Health and Alarm Logs SHALL subscribe to HAL (or App façades) for lights/temps as today, and SHALL consume historical log streams/APIs from the App façade over `cyber_alarm`. Monitor MUST NOT implement warn episode policy or open a second warn dialog stack local to Machine Status. Hiding or leaving Machine Status MUST NOT stop App-lifetime `WarnAlarmController` / `WarnAlarmScope`.

#### Scenario: No tab-local episode controller

- **WHEN** Machine Status is open and a Modbus alarm rises
- **THEN** modal warn presentation is performed by the App-wide presentation host backed by `cyber_alarm`
- **AND** Machine Status does not create a parallel episode state machine

#### Scenario: Warn controller outlives Machine Status

- **WHEN** the operator leaves Machine Status for Work Info, Videos, AI Vision, or another route
- **THEN** `WarnAlarmController` SHALL continue running
- **AND** subsequent rising edges SHALL still present via the App warn host

### Requirement: Monitor chrome and labels use App localization

Monitor shell title, tab labels, and migrated operator-visible row/tile labels SHALL use `AppLocalizations` for the active UI locale. Alarm Logs list labels for catalogued codes SHALL follow the same localization resolution as warn presentation (`cyber-alarm` / App catalog keys). New Machine Status section titles (Device Health, and Live Status if shown) SHALL be localized.

#### Scenario: Monitor title follows locale

- **WHEN** Language is `zh-CN` and the operator opens Monitor
- **THEN** the Monitor page status-bar title and migrated tab labels render in Simplified Chinese

#### Scenario: Machine Status labels follow locale

- **WHEN** Language is `zh-CN` and the operator opens Machine Status
- **THEN** migrated gauge, run-tile, Device Health, and Alarm Logs labels render in Simplified Chinese via App localization

## REMOVED Requirements

### Requirement: Monitor presents active alarms from HAL attributes

**Reason:** A dedicated Monitor active-alarm list duplicates Alarm Logs (history) and the App-wide warn frost (live episodes). The product page is Live Status → Device Health → Alarm Logs only.

**Migration:** Live episodes remain on the App `cyber_alarm` presentation host. Communication and over-temperature health remain on Machine Status Device Health. Historical onsets remain on Machine Status Alarm Logs. HAL `watchAttributes` / no App Timer poll is required by Device Health and Live Status requirements above. C002 history is covered by Alarm Logs.
