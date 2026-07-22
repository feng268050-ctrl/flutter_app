## Why

IP-camera health and Home/Monitor status chrome already exist (`IpCameraProductSession` / HAL `ip_camera`), and the warn stack (`cyber_alarm` + `WarnAlarmController`) already owns episodes, dialogs, history, severity bypass, and laser soft-interrupt — but camera reachability is **not yet an `AlarmSignalSource`**. Without that thin App adapter, operators only see icon/tile changes; C002 stays demo-only (`make alarm CODE=C002`).

## What Changes

- Add an App adapter that maps existing HAL **`IpCameraController.health`** edges to `cyber_alarm` **`AlarmSignalEvent`** for catalog code **C002** (already seeded), using the same inbound port Modbus already uses.
- Merge that adapter with the existing Modbus `AlarmSignalSource` into the single `WarnAlarmCoordinator` feed already owned by `WarnAlarmController`.
- Reuse existing **`BootSelfCheckWarnGate`**, presentation host, catalog copy, **`LaserAlarmPolicy` / `allowWorkAfterCameraAlarm`**, and **`LaserWorkGuard`** — no parallel camera warn pipeline.
- Extend warn SFX sync so INFO-styled bypassable codes (via existing `treatBypassableAsInfo`) do not loop warn sound.
- HAL stays health-only; no new ping scheduler, eth0, MediaMTX, or dialog logic in HAL/`cyber_alarm` domain.

## Capabilities

### New Capabilities

- `camera-communication-alarm`: Wire IP-camera health into the existing warn stack as non-Modbus C002 (raise/clear via `AlarmSignalSource`; reuse gate, dialog, history, policy).

### Modified Capabilities

- `cyber-alarm`: Clarify that Apps MAY merge multiple `AlarmSignalSource` adapters into one coordinator without changing episode policy; presentation gate applies to all sources equally.
- `product-monitor-ui`: Active Alarm Information list SHALL include coordinator episodes from non-Modbus sources (C002), not only Modbus `alarm.*` attributes.
- `advanced-settings-warn-severity`: INFO-styled bypassable codes (via existing policy) MUST NOT play the looping warn alarm sound.

## Impact

- App: thin camera→`AlarmSignalSource` adapter; merge in `WarnAlarmController`; optional LaserWorkGuard on edges; SFX filter via existing policy helpers.
- Depends on main-spec `ip-camera` / in-tree HAL `ip_camera` health + product session + `cyber_alarm` ports (baseline from archived `ipc-camera-async-status`).
- Does **not** port lws-ui classes (`CameraCommunicationMonitor`, `ExternalWarnAlarm`, MemoryCache listeners, etc.). Product code **C002** and operator outcomes reuse this repo’s catalog/policy; lws-ui is reference only for “camera unreachable should warn,” not an implementation template.
- Out of scope: L001/H034 adapters; camera version HTTP cache; RGB LED; reworking eth0/MediaMTX/Home icon.
