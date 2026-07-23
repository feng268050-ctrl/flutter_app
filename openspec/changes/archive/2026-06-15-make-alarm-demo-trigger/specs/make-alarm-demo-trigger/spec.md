## ADDED Requirements

### Requirement: Demo alarm trigger via adb broadcast

When not running a production release-channel build, the app SHALL register a non-exported `BroadcastReceiver` for action `com.lasercyber.lws.ui.action.DEMO_ALARM` with string extra `code` (alarm code such as `C002`). On receive, the handler SHALL resolve the code via `AlarmCodeEnums`, build a `WarnDialogVo` using the same title/content/severity factories as production alarms, mark the code as a demo-sticky episode, arm `WarnCacheManager`, enqueue a passive warn dialog through `DeviceDialogHandler`, and call `LaserWorkGuard.evaluateAndInterruptIfNeeded`.

#### Scenario: Valid alarm code on staging build

- **WHEN** a broadcast is sent with `code=C002` while `BuildConfig.RELEASE_CHANNEL` is false and the code exists in `AlarmCodeEnums`
- **THEN** the app SHALL show the C002 camera communication alarm dialog with production title and body strings
- **AND** the dialog SHALL remain visible until the operator dismisses it

#### Scenario: Unknown alarm code

- **WHEN** a broadcast is sent with an unknown or empty `code`
- **THEN** the app SHALL NOT show a dialog
- **AND** SHALL log a diagnosable message (for example `demo_alarm_unknown_code`)

#### Scenario: Release channel ignores trigger

- **WHEN** `BuildConfig.RELEASE_CHANNEL` is true and a demo alarm broadcast is received
- **THEN** the app SHALL NOT show a dialog and SHALL NOT mark demo-sticky state

### Requirement: Demo alarm dialogs do not auto-close on fault recovery

While an alarm code is marked demo-sticky, automatic warn teardown (`DeviceStatusConvert.closeWarn` and equivalent auto-dismiss paths driven by Modbus polling or external fault cleared, e.g. camera ping recovery for C002) SHALL NOT dismiss the dialog or clear warn cache for that code. When the operator dismisses the demo dialog, the app SHALL clear the demo-sticky mark for that code so normal auto-close behavior resumes for future episodes.

#### Scenario: Camera ping recovers during C002 demo

- **WHEN** C002 was triggered via demo broadcast and camera ping subsequently reports reachable
- **THEN** the C002 warn dialog SHALL remain visible
- **AND** `closeWarn` SHALL NOT remove the dialog for C002 while demo-sticky is set

#### Scenario: Operator dismisses demo dialog

- **WHEN** the operator closes the demo-triggered warn dialog
- **THEN** the demo-sticky mark for that code SHALL be cleared
- **AND** subsequent real fault recovery MAY auto-close that code per existing production rules

### Requirement: Demo alarm follows production laser interrupt rules

Demo-triggered alarms SHALL use the same laser interrupt semantics as `alarm-laser-interrupt`: all demo-sticky `AlarmCodeEnums` codes SHALL participate in `LaserEnableAlarmGuard.isWorkBlocked` while sticky; only A001, C002, and L001 MAY be exempt when the matching dangerous-operations bypass toggle is ON.

#### Scenario: E006 demo forces laser off

- **WHEN** a demo broadcast triggers E006 while laser enable is active
- **THEN** `LaserWorkGuard.evaluateAndInterruptIfNeeded` SHALL force laser off
- **AND** no dangerous-operations toggle SHALL prevent that interrupt

#### Scenario: C002 demo with bypass OFF forces laser off while ping healthy

- **WHEN** a demo broadcast triggers C002, laser enable is active, camera ping reports reachable, and `allowWorkAfterCameraAlarm` is false
- **THEN** the app SHALL force laser enable off
- **AND** the C002 warn dialog SHALL remain visible until the operator dismisses it

#### Scenario: C002 demo with bypass ON does not force laser off

- **WHEN** a demo broadcast triggers C002, laser enable is active, and `allowWorkAfterCameraAlarm` is true
- **THEN** the app SHALL NOT force laser off solely because of the demo C002 episode
- **AND** the demo warn dialog SHALL still be shown
