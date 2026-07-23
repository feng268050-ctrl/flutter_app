## ADDED Requirements

### Requirement: All coded alarm popups interrupt active laser work

While laser enable is active in Quick Mode or Engineer Mode, whenever a production warn dialog is shown or a warn episode becomes active for an alarm code defined in `AlarmCodeEnums`, the app SHALL treat that code as blocking work and SHALL force laser enable off via `LaserWorkGuard` (registered host `forceLaserOffForGuardedAlarm` or equivalent `deviceStatusListen` path using `LaserEnableAlarmGuard.isWorkBlocked`). This rule applies to **all** `AlarmCodeEnums` codes that have an active warn episode (`WarnCacheManager.isWarn`) or are shown through the warn dialog pipeline with a non-empty `errorCode` matching `AlarmCodeEnums`.

Warn dialogs **without** an `errorCode`, or with a code not in `AlarmCodeEnums`, SHALL NOT trigger this runtime laser interrupt rule.

Laser **disable** / end-of-work actions SHALL NOT be blocked by this requirement.

#### Scenario: Modbus serious alarm forces laser off at runtime

- **WHEN** laser enable is active
- **AND** a Modbus-driven warn episode becomes active for code **E006** (pump module overtemperature)
- **AND** the operator has not dismissed the warn episode
- **THEN** the app SHALL force laser enable off before or when the E006 warn dialog is shown
- **AND** laser disable MUST remain available

#### Scenario: Passive warn shown triggers immediate interrupt

- **WHEN** laser enable is active
- **AND** `DeviceDialogHandler.showPassiveWarnDialog` enqueues a warn dialog with `errorCode=H008`
- **THEN** the app SHALL call `LaserWorkGuard.evaluateAndInterruptIfNeeded`
- **AND** laser enable SHALL be forced off via the registered host or the next `isWorkBlocked` evaluation

#### Scenario: Warn dialog without error code does not interrupt

- **WHEN** laser enable is active
- **AND** a warn-class dialog is shown with null or empty `errorCode`
- **THEN** the app SHALL NOT force laser off solely because of that dialog

### Requirement: Only A001 C002 L001 support dangerous-operations bypass for laser work

For alarm codes **A001** (shielding gas), **C002** (camera communication), and **L001** (lens heavy contamination) only, when the matching Advanced Settings dangerous-operations bypass toggle is **ON** and the alarm is active, the app SHALL NOT block laser enable and SHALL NOT force laser off at runtime **for that alarm code**.

For every other `AlarmCodeEnums` code, no dangerous-operations bypass exists: an active warn episode SHALL always block laser enable (via existing `quickCheckDeviceStatus` / preflight paths where applicable) and SHALL force laser off at runtime while laser is on.

#### Scenario: E006 has no bypass

- **WHEN** E006 is active and laser enable is on
- **THEN** the app SHALL force laser off
- **AND** turning ON any dangerous-operations toggle MUST NOT allow laser to remain enabled because of E006 alone

#### Scenario: C002 bypass ON allows laser while fault active

- **WHEN** C002 is active, `allowWorkAfterCameraAlarm` is true, and all other preflight checks pass
- **THEN** the app SHALL NOT force laser off solely because of C002
- **AND** the operator MAY enable or keep laser on

#### Scenario: A001 bypass OFF forces laser off

- **WHEN** A001 is active, `allowWorkAfterGasAlarm` is false, and laser enable is on
- **THEN** the app SHALL force laser enable off
