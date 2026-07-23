# boot-self-check Specification

## Purpose

Run a one-per-process synchronous self-check when the operator first reaches the HMI home page, covering Modbus alarm-information items and camera ICMP connectivity, while suppressing overlapping async warn popups until completion.

## Requirements

### Requirement: Boot self-check triggers once per process when home page is entered

When the operator reaches the HMI home page (`MainActivity` home layout visible for the first time in the process), the app SHALL start a **boot self-check** sequence exactly **once per process lifetime**. Subsequent home entries in the same process MUST NOT re-run the self-check.

#### Scenario: First home entry starts self-check

- **WHEN** `MainActivity` initializes the home view for the first time in the process
- **THEN** the boot self-check coordinator SHALL begin the synchronous check pipeline
- **AND** a self-check progress dialog SHALL be shown

#### Scenario: Second home entry skips self-check

- **WHEN** the operator navigates away from home and returns within the same process
- **AND** boot self-check has already completed in this process
- **THEN** the self-check dialog MUST NOT be shown again
- **AND** `CameraCommunicationMonitor` SHALL be started if not already running

### Requirement: Self-check dialog appends items and status incrementally

During boot self-check, the app SHALL display a self-check progress dialog hosted by `FrostedGlassDialog` with a custom body that lists each check item. For every item, the dialog SHALL first append the item label with status **checking**, then update that row to **pass** or **fail** when the check completes. Manual close, auto-dismiss, and "do not show again" behavior MUST remain equivalent to the pre-migration `BootSelfCheckDialog`.

#### Scenario: Self-check dialog uses FrostedGlass overlay

- **WHEN** boot self-check starts on first home entry
- **THEN** the progress dialog MUST render as a `FrostedGlassDialog` overlay with incremental item rows in the custom body slot
- **AND** MUST NOT use a standalone legacy `Dialog` window as the primary visual container

#### Scenario: Item transitions from checking to pass

- **WHEN** a check item begins execution
- **THEN** the dialog SHALL append a row with the localized item name and status **checking**
- **WHEN** the item evaluation concludes healthy
- **THEN** that row SHALL update to status **pass**

#### Scenario: Item transitions from checking to fail

- **WHEN** a check item begins execution
- **THEN** the dialog SHALL append a row with status **checking**
- **WHEN** the item evaluation concludes unhealthy or times out
- **THEN** that row SHALL update to status **fail**

#### Scenario: Dialog auto-closes after all items complete

- **WHEN** every scheduled check item has reached a terminal status (pass, fail, or skipped)
- **THEN** the self-check dialog SHALL dismiss automatically without operator action

### Requirement: Self-check covers Modbus alarm-information checks and camera connectivity

The boot self-check pipeline SHALL evaluate, in order, the Modbus-backed checks aligned with Monitor → Alarm Information left panel and one camera ICMP connectivity check:

1. Lower-controller communication (valid `DeviceStatus` with `deviceType > 0`)
2. Pump comm status
3. Gun head comm status
4. Motor driver board temperature
5. Gun motor temperature
6. Protective mirror temperature
7. Collimator temperature
8. Wire feeder comm status
9. Camera comm status (ICMP ping via `CameraUtils.checkCameraBlocking()` or equivalent)

Item labels SHALL use the same localized string resources as the Alarm Information tiles where applicable.

#### Scenario: Modbus checks use synchronous reads

- **WHEN** a Modbus-backed check item runs
- **THEN** the coordinator SHALL obtain fresh `DeviceStatus` and/or `DeviceData` via synchronous Modbus input register reads
- **AND** each item SHALL be evaluated with the same alarm semantics as Alarm Information (including readiness and `alarmMetric` rules for temperature tiles)

#### Scenario: Camera check uses ping only

- **WHEN** the camera comm status item runs
- **THEN** the app SHALL evaluate reachability using the ping health module with a bounded timeout
- **AND** the check MUST NOT call `GET /System/deviceinfo` solely for connectivity

#### Scenario: Controller unreachable skips dependent Modbus items

- **WHEN** lower-controller communication fails or times out
- **THEN** subsequent Modbus-dependent items SHALL be marked **skipped** or **fail** without blocking the camera item
- **AND** the camera comm status item SHALL still execute

### Requirement: Async detection is suppressed during boot self-check

While boot self-check is active, the app SHALL suppress asynchronous detection side effects that overlap with the self-check:

- `DeviceDialogHandler` MUST NOT present Modbus-driven warn popups
- `CameraCommunicationMonitor` (periodic ping scheduler and C002 alarm listener) MUST NOT be running

#### Scenario: Modbus alarm popup suppressed during self-check

- **WHEN** boot self-check is active
- **AND** a Modbus device-status poll detects an alarm condition
- **THEN** `DeviceDialogHandler` MUST NOT show a warn popup

#### Scenario: Camera monitor not started during self-check

- **WHEN** boot self-check is active
- **THEN** the 1 Hz camera ping scheduler SHALL NOT be running
- **AND** C002 camera communication popups SHALL NOT be raised

### Requirement: Async detection resumes after self-check completes

When boot self-check finishes (dialog dismissed), the app SHALL re-enable asynchronous detection:

- `DeviceDialogHandler` SHALL resume normal warn popup behavior
- `CameraCommunicationMonitor.startWhenHomeEntered` SHALL be invoked if not already started

#### Scenario: Camera monitor starts after self-check

- **WHEN** boot self-check completes
- **THEN** `CameraCommunicationMonitor` SHALL start the periodic ping schedule and C002 alarm listener

#### Scenario: Modbus popup resumes after self-check

- **WHEN** boot self-check completes
- **AND** a subsequent Modbus poll detects an alarm
- **THEN** `DeviceDialogHandler` SHALL present warn popups per existing rules

### Requirement: Boot self-check synchronous Modbus reads use serial command gate

Synchronous Modbus input register reads performed during boot self-check (including `readDeviceStatusBlocking` and `readFullModbusSnapshotBlocking`) SHALL pass through the same `ModbusSerialGate` used at runtime so that spacing between the status read and data read in a full snapshot, and between snapshot reads and any concurrent serial traffic, follows `COMMAND_INTERVAL_MS`.

#### Scenario: Full snapshot respects command interval between status and data

- **WHEN** boot self-check performs a full Modbus snapshot (device status then device data)
- **THEN** the app SHALL enforce at least `COMMAND_INTERVAL_MS` between the end of the status read and the start of the data read
- **AND** SHALL complete both reads before evaluating Modbus-backed check items

#### Scenario: Self-check does not bypass gate on production hardware

- **WHEN** boot self-check runs on production hardware with Modbus RTU connected
- **THEN** synchronous Modbus reads SHALL NOT bypass the serial command gate
