## MODIFIED Requirements

### Requirement: Only A001 C002 L001 support dangerous-operations bypass for laser work

For alarm codes **A001** (shielding gas), **C002** (camera communication), **L001** (lens heavy contamination), **W001** (wire feeder communication), and **W002** (wire feeder current), when the matching Advanced Settings dangerous-operations bypass toggle is **ON** and the alarm is active, the app SHALL NOT block laser enable and SHALL NOT force laser off at runtime **for that alarm code** (unless superseded by turning **OFF** `keepLaserOnWhileAlarmed` while other blocking rules apply — preflight unchanged).

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

#### Scenario: Feeder bypass ON allows laser while fault active

- **WHEN** W001 or W002 is active
- **AND** `allowWorkAfterFeederAlarm` is true
- **AND** all other preflight checks pass
- **THEN** the app SHALL NOT force laser off solely because of the feeder alarm
- **AND** the operator MAY enable or keep laser on in any process type

#### Scenario: Feeder bypass OFF forces laser off

- **WHEN** W001 or W002 is active
- **AND** `allowWorkAfterFeederAlarm` is false
- **AND** `keepLaserOnWhileAlarmed` is false
- **AND** laser enable is on
- **THEN** the app SHALL force laser enable off
