## ADDED Requirements

### Requirement: Bypass toggles downgrade warn dialog severity to info

When a **Allow Work after … Alarm** bypass toggle is **ON**, passive and laser-enable warn dialogs for the matching alarm code MUST use `INFO_TYPE` instead of `WARN_TYPE`. When the toggle is **OFF**, those dialogs MUST use `WARN_TYPE`.

This applies to:

| Toggle | Alarm codes |
|--------|-------------|
| `allowWorkAfterCameraAlarm` | C002 |
| `allowWorkAfterGasAlarm` | A001 |
| `allowWorkAfterLensContamination` | L001 |
| `allowWorkAfterFeederAlarm` | W001, W002 |

Toggling any bypass switch MUST trigger `GpioLedHandler.refresh()` so yellow LED state reflects the new severity.

#### Scenario: Enabling camera bypass changes dialog style

- **WHEN** C002 is active and a warn dialog is shown
- **AND** the operator turns ON Allow Work after Camera Alarm
- **THEN** subsequent C002 dialogs MUST use `INFO_TYPE`
- **AND** the yellow LED MUST turn off if C002 was the only `WARN_TYPE` alarm

#### Scenario: Disabling gas bypass restores warn dialog

- **WHEN** A001 is active
- **AND** `allowWorkAfterGasAlarm` changes from true to false
- **THEN** the next A001 warn dialog MUST use `WARN_TYPE`
- **AND** MUST play warn alarm sound

## MODIFIED Requirements

### Requirement: Dangerous operations toggles gate laser-enable alarm blocking

When the operator initiates **laser enable** in Quick Mode or Engineer Mode, the app SHALL evaluate camera communication (C002), shielding gas (A001), and lens heavy contamination (L001) laser-enable guards **before** sending laser-on Modbus commands.

For each of these **three** alarm types only:

- When the corresponding dangerous-operations toggle is **OFF** and the alarm is **active**, laser enable MUST be blocked and the operator MUST see the corresponding warn dialog again on that attempt (immediate warn queue, same copy as passive alarms) with `WARN_TYPE`.
- When the corresponding toggle is **ON** and the alarm is still active, that alarm MUST NOT block laser enable and MUST NOT enqueue a repeat warn dialog solely because of that alarm on that attempt. If a dialog is shown for other reasons, it MUST use `INFO_TYPE`.

For all other `AlarmCodeEnums` alarm codes, dangerous-operations toggles MUST NOT apply to laser-enable blocking except **W001** and **W002** which follow `allowWorkAfterFeederAlarm` per `alarm-laser-interrupt`. Active alarms without a matching bypass MUST continue to block laser enable (where the existing Modbus preflight applies) and MUST force laser off at runtime per `alarm-laser-interrupt` unless **Keep Laser On while Alarmed** is ON.

**Keep Laser On while Alarmed** MUST NOT change laser-enable preflight for any alarm code. It affects **runtime** laser interrupt only (see `alarm-laser-interrupt`).

Laser **disable** / end-of-work actions MUST NOT be blocked by these guards.

While laser enable is active in Quick Mode or Engineer Mode, when a guarded alarm (C002, A001, or unresolved L001) is active and the matching bypass toggle is **OFF** and `keepLaserOnWhileAlarmed` is **OFF**, the app MUST force laser enable off (runtime work guard) without blocking laser disable. When any **other** coded alarm is active and `keepLaserOnWhileAlarmed` is **OFF**, the app MUST force laser enable off with **no** per-alarm dangerous-operations exemption. When `keepLaserOnWhileAlarmed` is **ON**, the app MUST NOT force laser off at runtime for any coded alarm while laser enable is active.

Laser-enable C002 blocking MUST use an active warn dialog path that is not suppressed by passive warn-cache reminder consumption. Blocking MUST occur even when dialog materialization returns null.

Only `WARN_TYPE` warn dialogs shown through the global warn dialog pipeline MUST play the warn alarm sound when displayed. `INFO_TYPE` dialogs MUST NOT play warn alarm sound.

Quick Mode laser enable SHALL run the same laser-power vs advanced-settings start/end power validation as Engineer Mode before `EngineerModeCheck.enableLaser`.

Active predicates:

| Alarm | Active when |
|-------|-------------|
| Camera C002 | Camera ping health reports unreachable (`CameraCommStatus.isFault()`) or demo-sticky C002 |
| Gas A001 | `ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)` or demo-sticky A001 |
| Lens L001 | A production heavy contamination episode is unresolved (detected heavy without level-0 / fault-cleared event, including after operator acknowledged the L001 dialog this boot) or demo-sticky L001 |

#### Scenario: Camera fault blocks laser enable by default

- **WHEN** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **AND** the operator taps laser enable in Quick Mode or Engineer Mode
- **THEN** laser enable MUST NOT proceed
- **AND** the operator MUST see the C002 camera communication warn dialog with `WARN_TYPE`

#### Scenario: Camera bypass allows laser enable

- **WHEN** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is true
- **AND** all other laser-enable preflight checks pass
- **THEN** laser enable MAY proceed
- **AND** the app MUST NOT show a repeat C002 popup solely for that laser-enable attempt

#### Scenario: Gas alarm blocks laser enable by default

- **WHEN** shielding gas alarm A001 is active
- **AND** `allowWorkAfterGasAlarm` is false
- **AND** the operator taps laser enable
- **THEN** laser enable MUST NOT proceed
- **AND** the operator MUST see the A001 shielding gas warn dialog with `WARN_TYPE`

#### Scenario: Gas bypass allows laser enable

- **WHEN** shielding gas alarm A001 is active
- **AND** `allowWorkAfterGasAlarm` is true
- **AND** all other laser-enable preflight checks pass
- **THEN** laser enable MAY proceed
- **AND** the app MUST NOT show a repeat A001 popup solely for that laser-enable attempt

#### Scenario: Lens contamination blocks repeat laser enable by default

- **WHEN** a production heavy lens contamination episode is unresolved (L001)
- **AND** `allowWorkAfterLensContamination` is false
- **AND** the operator taps laser enable after previously acknowledging the L001 dialog
- **THEN** laser enable MUST NOT proceed
- **AND** the operator MUST see the L001 heavy contamination warn dialog again with `WARN_TYPE`

#### Scenario: Lens contamination bypass allows laser enable

- **WHEN** a production heavy lens contamination episode is unresolved (L001)
- **AND** `allowWorkAfterLensContamination` is true
- **AND** all other laser-enable preflight checks pass
- **THEN** laser enable MAY proceed
- **AND** the app MUST NOT show a repeat L001 popup solely for that laser-enable attempt

#### Scenario: Laser disable not blocked by dangerous guards

- **WHEN** any of C002, A001, or unresolved L001 is active
- **AND** laser is currently ON
- **AND** the operator initiates laser disable or end-of-work
- **THEN** laser disable MUST proceed without dangerous-operations preflight blocking

#### Scenario: Active guarded alarm forces laser off at runtime

- **WHEN** laser enable is active in Quick Mode or Engineer Mode
- **AND** a guarded alarm (C002, A001, or unresolved L001) is active
- **AND** the matching dangerous-operations bypass toggle is OFF
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app MUST force laser enable off
- **AND** laser disable MUST NOT be blocked by dangerous guards

#### Scenario: Keep laser on while alarmed suppresses runtime interrupt

- **WHEN** laser enable is active
- **AND** any coded alarm (for example E006 or C002) is active
- **AND** `keepLaserOnWhileAlarmed` is true
- **THEN** the app MUST NOT force laser enable off solely because of that alarm
- **AND** warn dialogs for that alarm MAY still be shown

#### Scenario: Turning off keep laser on while alarmed restores interrupt

- **WHEN** laser enable is active
- **AND** a coded alarm is active
- **AND** the operator turns OFF Keep Laser On while Alarmed
- **THEN** the app MUST evaluate runtime interrupt and force laser off if alarms still block work per default rules

#### Scenario: Non-trio coded alarm forces laser off without bypass

- **WHEN** laser enable is active
- **AND** a coded alarm other than A001, C002, or L001 (for example E006) is active
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app MUST force laser enable off
- **AND** no per-alarm dangerous-operations toggle MAY exempt that alarm from runtime interrupt

#### Scenario: C002 laser-enable block plays warn sound

- **WHEN** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **AND** the operator taps laser enable
- **THEN** laser enable MUST NOT proceed
- **AND** the C002 warn dialog MUST be shown with `WARN_TYPE` and warn alarm sound

#### Scenario: Quick Mode validates laser power before enable

- **WHEN** the operator taps laser enable in Quick Mode
- **AND** process laser power does not exceed advanced-settings start or end power thresholds
- **THEN** laser enable MUST NOT proceed
- **AND** the app MUST show the existing laser power validation message
