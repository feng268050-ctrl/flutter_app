# alarm-comm-status-platform-display Specification

## Purpose
TBD - created by archiving change monitor-comm-status-emulator-device-colors. Update Purpose after archive.
## Requirements
### Requirement: Comm Status indicators use platform-aware three-state display

On the Alarm Information screen, the Pump Comm Status, Gun Comm Status, Feeder Comm Status, and **Camera Comm Status** indicators SHALL render exactly one of three visual states: **healthy** (green), **fault** (red), or **neutral** (gray). Indicators MUST be `FrostStatusIndicatorView` with **Icon** variant (green/red background with white checkmark/cross; gray background with no glyph when neutral). For Pump, Gun, and Feeder, the state SHALL be derived from `statusReady`, the corresponding communication alarm bit on `DeviceStatus`, and whether the app is running on an emulator. For **Camera Comm Status**, the communication fault signal SHALL be derived from camera **ping reachability** (`CameraCommStatus` / ping health module: unreachable = fault). On production hardware, Camera Comm Status SHALL use the same three-state rules as Modbus comm tiles (`statusReady` + emulator). On an emulator, when `camera_ip` is present in ROM (`/system/etc/model.properties`, e.g. via `CAMERA_IP` / `make emulator`), Camera Comm Status SHALL reflect the ping probe directly (green when reachable, red when unreachable) and MUST NOT use the neutral gray state for camera faults or health.

Mapping to `FrostStatusState`: HEALTHY → Success, FAULT → Failure, NEUTRAL → Idle.

#### Scenario: Emulator with no controller communication

- **WHEN** the app runs on an emulator and `statusReady` is false (no valid lower-controller status yet)
- **THEN** each Comm Status indicator (including Camera) SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with active Modbus communication alarm

- **WHEN** the app runs on an emulator, `statusReady` is true, and a Pump/Gun/Feeder communication fault is active (Modbus alarm bit set)
- **THEN** that Modbus Comm Status indicator SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with healthy Modbus communication

- **WHEN** the app runs on an emulator, `statusReady` is true, and the Modbus communication fault for Pump/Gun/Feeder is inactive
- **THEN** that Modbus Comm Status indicator SHALL display the **healthy** (green checkmark) state.

#### Scenario: Emulator with configured camera host and ping fault

- **WHEN** the app runs on an emulator, `camera_ip` is configured in ROM, and ping health reports unreachable
- **THEN** the Camera Comm Status indicator SHALL display the **fault** (red cross) state and MUST NOT display the neutral (gray) state.

#### Scenario: Emulator with configured camera host and ping healthy

- **WHEN** the app runs on an emulator, `camera_ip` is configured in ROM, and ping health reports reachable
- **THEN** the Camera Comm Status indicator SHALL display the **healthy** (green checkmark) state regardless of `statusReady`.

#### Scenario: Emulator without configured camera host

- **WHEN** the app runs on an emulator and `camera_ip` is absent from ROM
- **THEN** Camera Comm Status SHALL follow the same emulator neutral rules as Modbus comm tiles (gray when not ready or when fault would otherwise show red on emulator).

#### Scenario: Real device with no controller communication

- **WHEN** the app runs on production hardware (non-emulator) and `statusReady` is false
- **THEN** each Comm Status indicator (including Camera) SHALL display the **fault** (red cross) state.

#### Scenario: Real device with active communication alarm

- **WHEN** the app runs on production hardware, `statusReady` is true, and a Comm Status communication fault is active
- **THEN** that Comm Status indicator SHALL display the **fault** (red cross) state.

#### Scenario: Real device with healthy communication

- **WHEN** the app runs on production hardware, `statusReady` is true, and the communication fault is inactive
- **THEN** that Comm Status indicator SHALL display the **healthy** (green checkmark) state.

#### Scenario: Version cache dash does not affect camera comm tile when ping is healthy

- **WHEN** `CameraDeviceInfoCache.getDisplay()` is `-`
- **AND** ping health reports reachable
- **THEN** Camera Comm Status SHALL display **healthy** (green checkmark) on production hardware when other gating conditions for healthy comm are met

### Requirement: Non-comm alarm tiles are unchanged

Temperature and other non-communication alarm tiles on the Alarm Information left panel SHALL continue to use readiness-gated expressions and existing red/green/gray semantics via `FrostStatusIndicatorView` (**Icon** variant). This capability SHALL NOT alter readiness or fault evaluation logic.

#### Scenario: Temperature tile offline on emulator

- **WHEN** the app runs on an emulator and `statusReady` or `dataReady` is false for a temperature tile
- **THEN** that tile SHALL display **Idle** (gray) per existing readiness gating, not the Comm Status neutral gray rules for Modbus comm tiles.

