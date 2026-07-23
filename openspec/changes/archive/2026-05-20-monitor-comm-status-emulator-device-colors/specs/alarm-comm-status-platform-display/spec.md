## ADDED Requirements

### Requirement: Comm Status indicators use platform-aware three-state display

On the Alarm Information screen, the Pump Comm Status, Gun Comm Status, and Feeder Comm Status indicators SHALL render exactly one of three visual states: **healthy** (green), **fault** (red), or **neutral** (gray). The state SHALL be derived from `statusReady`, the corresponding communication alarm bit on `DeviceStatus`, and whether the app is running on an emulator.

#### Scenario: Emulator with no controller communication

- **WHEN** the app runs on an emulator and `statusReady` is false (no valid lower-controller status yet)
- **THEN** each Comm Status indicator SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with active communication alarm

- **WHEN** the app runs on an emulator, `statusReady` is true, and a Comm Status communication alarm bit is set (missing comm)
- **THEN** that Comm Status indicator SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with healthy communication

- **WHEN** the app runs on an emulator, `statusReady` is true, and the communication alarm bit for a Comm Status tile is clear
- **THEN** that Comm Status indicator SHALL display the **healthy** (green) state.

#### Scenario: Real device with no controller communication

- **WHEN** the app runs on production hardware (non-emulator) and `statusReady` is false
- **THEN** each Comm Status indicator SHALL display the **fault** (red) state.

#### Scenario: Real device with active communication alarm

- **WHEN** the app runs on production hardware, `statusReady` is true, and a Comm Status communication alarm bit is set
- **THEN** that Comm Status indicator SHALL display the **fault** (red) state.

#### Scenario: Real device with healthy communication

- **WHEN** the app runs on production hardware, `statusReady` is true, and the communication alarm bit is clear
- **THEN** that Comm Status indicator SHALL display the **healthy** (green) state.

### Requirement: Non-comm alarm tiles are unchanged

Temperature and other non-communication alarm tiles on the Alarm Information left panel SHALL continue to use readiness-gated checked expressions and existing red/green semantics; this capability SHALL NOT alter their behavior.

#### Scenario: Temperature tile offline on emulator

- **WHEN** the app runs on an emulator and `statusReady` or `dataReady` is false for a temperature tile
- **THEN** that tile SHALL continue to show unchecked (fault/red) per existing readiness gating, not the Comm Status neutral gray state.
