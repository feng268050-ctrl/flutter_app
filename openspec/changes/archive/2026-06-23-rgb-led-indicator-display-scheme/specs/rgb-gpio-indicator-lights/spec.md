## ADDED Requirements

### Requirement: Tablet RGB indicators follow operator semantics

The YNH tablet GPIO RGB indicators SHALL communicate three independent operator concepts:

| LED | Role | Off means | Blink (1 Hz) means | Steady on means |
|-----|------|-----------|--------------------|-----------------|
| Red | Laser indicator | Laser not powered on or not connected to the control card | Laser online, **standby** (communicating, not emitting) | Laser **emitting** |
| Yellow | Alarm indicator | System has **no** hardware alarm in scanned Modbus segments | System has at least one hardware alarm | *(not used)* |
| Green | Ready indicator | Machine is **not ready** to emit | *(not used)* | Machine is **ready** to emit (interlocks satisfied, Laser Enable on, not emitting) |

Signal mapping:

- Laser emitting: `DeviceStatus.isLaserOn()` (`machineStatusSeg1` bit 0).
- Laser not connected / not powered on: `DeviceStatus.isLaserCommunicationAlarm()` (`laserAlarmSeg1` bit 0, H022).
- Hardware alarms: non-zero gun / laser / wire feeder / control card alarm segments (`DeviceStatus.hasAnyHardwareAlarm()`).
- Ready interlocks (standard modes): safety ground lock conducting, key switch on, and Laser Enable active in the work screen.
- CNC Cut ready: `DeviceStatus.isConnectCNC()` (`machineStatusSeg1` bit 10) and key switch on while active work model is CNC Cut.
- Green ready block: `LaserEnableAlarmGuard.isReadyIndicatorBlocked()` — coded alarms with advanced-setting bypass for A001 / C002 / L001 only (`keepLaserOnWhileAlarmed` does **not** affect green).

#### Scenario: Operator reads laser standby vs offline

- **WHEN** laser communication is healthy and laser is not emitting
- **THEN** the red indicator MUST blink at 1 Hz to mean standby
- **AND** the red indicator MUST NOT be steady on

#### Scenario: Operator reads laser offline

- **WHEN** laser communication alarm is active
- **THEN** the red indicator MUST be off
- **AND** MUST NOT blink (standby blink is only when communication is healthy)

### Requirement: Red LED indicates laser online, standby, and emit

The application SHALL drive the red GPIO indicator as follows:

- **Steady on** when `DeviceStatus.isLaserOn()` is true (emitting).
- **Off** when `DeviceStatus.isLaserCommunicationAlarm()` is true (laser not powered on or not connected).
- **Blink at 1 Hz** (500 ms on, 500 ms off) when laser is not emitting **and** laser communication alarm is **not** active (online standby).

#### Scenario: Laser emitting — red steady on

- **WHEN** Modbus device status reports laser on
- **THEN** the red GPIO indicator MUST be steady on
- **AND** any red blink scheduled task MUST be cancelled

#### Scenario: Laser communication alarm — red off

- **WHEN** `DeviceStatus.isLaserCommunicationAlarm()` is true
- **THEN** the red GPIO indicator MUST be off
- **AND** MUST NOT blink at 1 Hz

#### Scenario: Laser standby — red blinks

- **WHEN** laser is not emitting
- **AND** laser communication alarm is not active
- **THEN** the red GPIO indicator MUST blink at 1 Hz

#### Scenario: Laser stops emitting but stays online

- **WHEN** device status changes from laser on to laser off
- **AND** laser communication remains healthy
- **THEN** the red LED MUST leave steady on
- **AND** MUST begin 1 Hz standby blink on the next LED refresh

### Requirement: Yellow LED indicates active hardware alarms

The application SHALL drive the yellow GPIO indicator as follows:

- **Blink at 1 Hz** when `DeviceStatus.hasAnyHardwareAlarm()` is true.
- **Off** when no scanned hardware alarm segment is active.

#### Scenario: Alarm active — yellow blinks

- **WHEN** any gun, laser, wire feeder, or control card alarm segment is non-zero
- **THEN** the yellow GPIO indicator MUST blink at 1 Hz

#### Scenario: No hardware alarm — yellow off

- **WHEN** all scanned alarm segments are zero
- **THEN** the yellow GPIO indicator MUST be off

### Requirement: Green LED indicates ready to emit

The application SHALL drive the green GPIO indicator **steady on** only when the machine is **ready**.

Green MUST be **off** when laser is emitting, when the key switch is off, or when `LaserEnableAlarmGuard.isReadyIndicatorBlocked()` is true.

#### Standard work modes (not CNC Cut)

**Steady on** when **all** of the following are true:

1. Laser Enable active in the work screen — `LaserEnableStateHolder`
2. Safety ground lock conducting — `DeviceStatus.isSafetyGroundLockLocked()`
3. Key switch on — `DeviceStatus.isKeySwitchOn()`
4. Laser not emitting — `!DeviceStatus.isLaserOn()`
5. Ready not blocked by coded alarms — `!LaserEnableAlarmGuard.isReadyIndicatorBlocked()`

#### CNC Cut (Quick Mode)

**Steady on** when **all** of the following are true:

1. Active work model is CNC Cut — `LaserEnableStateHolder.getActiveWorkModel() == CNC_CUT`
2. CNC connected — `DeviceStatus.isConnectCNC()`
3. Key switch on — `DeviceStatus.isKeySwitchOn()`
4. Laser not emitting — `!DeviceStatus.isLaserOn()`
5. Ready not blocked by coded alarms — `!LaserEnableAlarmGuard.isReadyIndicatorBlocked()`

CNC ready MUST NOT depend on Laser Enable, safety ground lock, air valve, or the `cncOpening` UI overlay.

In all other cases the green LED MUST be **off**.

#### Scenario: Ready — green steady on (standard mode)

- **WHEN** Laser Enable is active, safety ground lock is conducting, key switch is on, laser is not emitting, and ready is not alarm-blocked
- **THEN** the green GPIO indicator MUST be steady on

#### Scenario: Ready — green steady on (CNC Cut)

- **WHEN** work model is CNC Cut, `isConnectCNC()` is true, key switch is on, laser is not emitting, and ready is not alarm-blocked
- **THEN** the green GPIO indicator MUST be steady on

#### Scenario: Not ready — green off

- **WHEN** any readiness condition for the active mode is not satisfied, or ready is alarm-blocked, or laser is emitting
- **THEN** the green GPIO indicator MUST be off

#### Scenario: Laser Enable toggled without waiting for poll

- **WHEN** the operator successfully toggles Laser Enable in Quick Mode or Engineer Mode
- **THEN** green (and red/yellow) LED state MUST refresh immediately

### Requirement: RGB LED decisions are centralized

GPIO indicator decisions MUST be computed in `GpioLedHandler` (via `RgbLedDecision` or equivalent). Production work screens MUST NOT call `GpioLedManager` directly for red/yellow/green behavior except Dev/debug tooling.

#### Scenario: Poll cycle drives LEDs

- **WHEN** a normal Modbus poll cycle completes `finishPollCycle`
- **THEN** `GpioLedHandler` MUST update red, yellow, and green from cached device status and laser-enable state

#### Scenario: No YNHAPI on emulator

- **WHEN** YNHAPI is unavailable
- **THEN** LED refresh MUST no-op without crashing
