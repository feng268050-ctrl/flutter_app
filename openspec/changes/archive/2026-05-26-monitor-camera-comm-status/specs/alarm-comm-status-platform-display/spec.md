## MODIFIED Requirements

### Requirement: Comm Status indicators use platform-aware three-state display

On the Alarm Information screen, the Pump Comm Status, Gun Comm Status, Feeder Comm Status, and **Camera Comm Status** indicators SHALL render exactly one of three visual states: **healthy** (green), **fault** (red), or **neutral** (gray). For Pump, Gun, and Feeder, the state SHALL be derived from `statusReady`, the corresponding communication alarm bit on `DeviceStatus`, and whether the app is running on an emulator. For **Camera Comm Status**, the communication fault signal SHALL be derived from camera HTTP cache connectivity (`CameraDeviceInfoCache` display `-` = fault), combined with `statusReady` and emulator detection using the same three-state rules as Modbus comm tiles.

#### Scenario: Emulator with no controller communication

- **WHEN** the app runs on an emulator and `statusReady` is false (no valid lower-controller status yet)
- **THEN** each Comm Status indicator (including Camera) SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with active communication alarm

- **WHEN** the app runs on an emulator, `statusReady` is true, and a Comm Status communication fault is active (Modbus alarm bit set, or camera cache display `-`)
- **THEN** that Comm Status indicator SHALL display the **neutral** (gray) state and MUST NOT display the fault (red) state.

#### Scenario: Emulator with healthy communication

- **WHEN** the app runs on an emulator, `statusReady` is true, and the communication fault for a Comm Status tile is inactive (Modbus bit clear and camera cache not `-`)
- **THEN** that Comm Status indicator SHALL display the **healthy** (green) state.

#### Scenario: Real device with no controller communication

- **WHEN** the app runs on production hardware (non-emulator) and `statusReady` is false
- **THEN** each Comm Status indicator (including Camera) SHALL display the **fault** (red) state.

#### Scenario: Real device with active communication alarm

- **WHEN** the app runs on production hardware, `statusReady` is true, and a Comm Status communication fault is active
- **THEN** that Comm Status indicator SHALL display the **fault** (red) state.

#### Scenario: Real device with healthy communication

- **WHEN** the app runs on production hardware, `statusReady` is true, and the communication fault is inactive
- **THEN** that Comm Status indicator SHALL display the **healthy** (green) state.
