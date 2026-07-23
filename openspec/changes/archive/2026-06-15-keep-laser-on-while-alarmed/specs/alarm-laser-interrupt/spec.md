## MODIFIED Requirements

### Requirement: All coded alarm popups interrupt active laser work

While laser enable is active in Quick Mode or Engineer Mode, whenever a production warn dialog is shown or a warn episode becomes active for an alarm code defined in `AlarmCodeEnums`, the app SHALL treat that code as blocking work and SHALL force laser enable off via `LaserWorkGuard` (registered host `forceLaserOffForGuardedAlarm` or equivalent `deviceStatusListen` path using `LaserEnableAlarmGuard.isWorkBlocked`) **unless** Advanced Settings `keepLaserOnWhileAlarmed` is **ON**. This rule applies to **all** `AlarmCodeEnums` codes that have an active warn episode (`WarnCacheManager.isWarn`) or are shown through the warn dialog pipeline with a non-empty `errorCode` matching `AlarmCodeEnums`.

When `keepLaserOnWhileAlarmed` is **ON**, coded alarms MUST still surface warn dialogs and play warn sound where applicable, but the app MUST NOT force laser enable off at runtime solely because of those alarms.

Warn dialogs **without** an `errorCode`, or with a code not in `AlarmCodeEnums`, SHALL NOT trigger this runtime laser interrupt rule.

Laser **disable** / end-of-work actions SHALL NOT be blocked by this requirement.

#### Scenario: Modbus serious alarm forces laser off at runtime

- **WHEN** laser enable is active
- **AND** a Modbus-driven warn episode becomes active for code **E006** (pump module overtemperature)
- **AND** the operator has not dismissed the warn episode
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app SHALL force laser enable off before or when the E006 warn dialog is shown
- **AND** laser disable MUST remain available

#### Scenario: Keep laser on while alarmed allows runtime work during E006

- **WHEN** laser enable is active
- **AND** E006 warn episode becomes active
- **AND** `keepLaserOnWhileAlarmed` is true
- **THEN** the app MUST NOT force laser enable off solely because of E006
- **AND** the E006 warn dialog MAY still be shown

#### Scenario: Passive warn shown triggers immediate interrupt

- **WHEN** laser enable is active
- **AND** `DeviceDialogHandler.showPassiveWarnDialog` enqueues a warn dialog with `errorCode=H008`
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app SHALL call `LaserWorkGuard.evaluateAndInterruptIfNeeded`
- **AND** laser enable SHALL be forced off via the registered host or the next `isWorkBlocked` evaluation

#### Scenario: Passive warn does not interrupt when keep laser on enabled

- **WHEN** laser enable is active
- **AND** a passive warn dialog with a coded `errorCode` is shown
- **AND** `keepLaserOnWhileAlarmed` is true
- **THEN** the app MUST NOT force laser off solely because of that warn episode

#### Scenario: Warn dialog without error code does not interrupt

- **WHEN** laser enable is active
- **AND** a warn-class dialog is shown with null or empty `errorCode`
- **THEN** the app SHALL NOT force laser off solely because of that dialog

### Requirement: Only A001 C002 L001 support dangerous-operations bypass for laser work

For alarm codes **A001** (shielding gas), **C002** (camera communication), and **L001** (lens heavy contamination) only, when the matching Advanced Settings dangerous-operations bypass toggle is **ON** and the alarm is active, the app SHALL NOT block laser enable and SHALL NOT force laser off at runtime **for that alarm code** (unless superseded by turning **OFF** `keepLaserOnWhileAlarmed` while other blocking rules apply — preflight unchanged).

For every other `AlarmCodeEnums` code, no per-alarm dangerous-operations bypass exists: an active warn episode SHALL always block laser enable (via existing `quickCheckDeviceStatus` / preflight paths where applicable) and SHALL force laser off at runtime while laser is on **unless** `keepLaserOnWhileAlarmed` is **ON**.

#### Scenario: E006 has no per-alarm bypass

- **WHEN** E006 is active and laser enable is on
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app SHALL force laser off
- **AND** turning ON any per-alarm dangerous-operations toggle MUST NOT allow laser to remain enabled because of E006 alone

#### Scenario: E006 runtime allowed with keep laser on while alarmed

- **WHEN** E006 is active, laser enable is on, and `keepLaserOnWhileAlarmed` is true
- **THEN** the app MUST NOT force laser off solely because of E006

#### Scenario: C002 bypass ON allows laser while fault active

- **WHEN** C002 is active, `allowWorkAfterCameraAlarm` is true, and all other preflight checks pass
- **THEN** the app SHALL NOT force laser off solely because of C002
- **AND** the operator MAY enable or keep laser on

#### Scenario: A001 bypass OFF forces laser off

- **WHEN** A001 is active, `allowWorkAfterGasAlarm` is false, `keepLaserOnWhileAlarmed` is false, and laser enable is on
- **THEN** the app SHALL force laser enable off
