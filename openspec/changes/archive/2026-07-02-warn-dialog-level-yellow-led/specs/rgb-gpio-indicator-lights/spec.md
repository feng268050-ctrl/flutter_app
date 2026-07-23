## MODIFIED Requirements

### Requirement: Tablet RGB indicators follow operator semantics

The YNH tablet GPIO RGB indicators SHALL communicate three independent operator concepts:

| LED | Role | Off means | Blink (2 s period) means | Steady on means |
|-----|------|-----------|----------------------------|-----------------|
| Red | Laser indicator | Laser not powered on or not connected to the control card | Laser online, **standby** (communicating, not emitting) | Laser **emitting** |
| Yellow | Alarm indicator | System has **no** active `WARN_TYPE` coded alarm | At least one active coded alarm resolves to `WARN_TYPE` | *(not used)* |
| Green | Ready indicator | Machine is **not ready** to emit | *(not used)* | Machine is **ready** to emit (mode-specific interlocks satisfied) |

Signal mapping:

- Laser emitting: `DeviceStatus.isLaserOn()` (`machineStatusSeg1` bit 0).
- Laser not connected / not powered on: `DeviceStatus.isLaserCommunicationAlarm()` (`laserAlarmSeg1` bit 0, H022).
- **Warn-severity alarms:** any active coded alarm whose resolved dialog type is `WARN_TYPE` per `warn-dialog-severity`, including Modbus hardware segments **and** non-Modbus sources (C002 camera ping fault, L001 lens heavy contamination).
- Ready interlocks (standard modes): safety ground lock conducting, key switch on, and Laser Enable active in the work screen.
- CNC Cut ready: `DeviceStatus.isConnectCNC()` (`machineStatusSeg1` bit 10) and key switch on while active work model is CNC Cut.
- Green ready block: `LaserEnableAlarmGuard.isReadyIndicatorBlocked()` — coded alarms with advanced-setting bypass for A001 / C002 / L001 only (`keepLaserOnWhileAlarmed` does **not** affect green).

#### Scenario: Operator reads laser standby vs offline

- **WHEN** laser communication is healthy and laser is not emitting
- **THEN** the red indicator MUST blink with a 2 s period (1 s on, 1 s off) to mean standby
- **AND** the red indicator MUST NOT be steady on

#### Scenario: Operator reads laser offline

- **WHEN** laser communication alarm is active
- **THEN** the red indicator MUST be off
- **AND** MUST NOT blink (standby blink is only when communication is healthy)

### Requirement: Yellow LED indicates active hardware alarms

The application SHALL drive the yellow GPIO indicator as follows:

- **Blink with a 2 s period** when any active coded alarm resolves to `WARN_TYPE` per `warn-dialog-severity` (Modbus and non-Modbus).
- **Off** when no active alarm resolves to `WARN_TYPE`.

#### Scenario: Alarm active — yellow blinks

- **WHEN** any active coded alarm resolves to `WARN_TYPE` (for example Modbus E006, camera C002 with camera bypass OFF, or L001 with lens bypass OFF)
- **THEN** the yellow GPIO indicator MUST blink with a 2 s period

#### Scenario: No hardware alarm — yellow off

- **WHEN** no active coded alarm resolves to `WARN_TYPE`
- **THEN** the yellow GPIO indicator MUST be off

#### Scenario: Camera comm fault blinks yellow

- **WHEN** C002 is active from camera ping health
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** the yellow GPIO indicator MUST blink with a 2 s period
- **AND** blink MUST occur even when Modbus hardware alarm segments are all zero

#### Scenario: Bypassed feeder alarm does not blink yellow alone

- **WHEN** only W001 is active
- **AND** `allowWorkAfterFeederAlarm` is true
- **THEN** the yellow GPIO indicator MUST be off

#### Scenario: Yellow refreshes on non-Modbus alarm edge

- **WHEN** camera communication transitions to fault or recovery
- **THEN** `GpioLedHandler` MUST refresh yellow (and other) LED state without waiting for the next Modbus poll
