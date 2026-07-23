## ADDED Requirements

### Requirement: Advanced Settings exposes Dangerous Operations toggle group

The Advanced Settings page SHALL include a titled group **Dangerous Operations** containing three Switch controls:

| Control | Persisted field | Default |
|---------|-----------------|---------|
| Allow Work after Camera Alarm | `allowWorkAfterCameraAlarm` | OFF (false) |
| Allow Work after Gas Alarm | `allowWorkAfterGasAlarm` | OFF (false) |
| Allow Work after Lens Contamination | `allowWorkAfterLensContamination` | OFF (false) |

All three fields SHALL be stored in `t_advanced_settings`. Labels MUST be localized (EN: group **Dangerous Operations**, items as named above; ZH equivalents in `values-zh`).

Each toggle row SHALL display a secondary hint line below the title explaining operator impact (camera AI availability, gas/lens equipment risk). Hint strings MUST be localized in EN and ZH.

#### Scenario: User views Dangerous Operations group

- **WHEN** the user opens Advanced Settings
- **THEN** the page displays the Dangerous Operations group below AI Assistance
- **AND** all three switches reflect persisted values from `t_advanced_settings`
- **AND** each switch shows its localized hint text below the title

#### Scenario: User enables allow work after gas alarm

- **WHEN** the user turns ON Allow Work after Gas Alarm
- **THEN** the app persists `allowWorkAfterGasAlarm` true in `t_advanced_settings`
- **AND** no Modbus device-setting write is sent solely because this toggle changed

#### Scenario: Fresh install defaults all dangerous toggles off

- **WHEN** the app creates the default `t_advanced_settings` row on first access
- **THEN** `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, and `allowWorkAfterLensContamination` MUST be false

### Requirement: Dangerous operations toggles gate laser-enable alarm blocking

When the operator initiates **laser enable** in Quick Mode or Engineer Mode, the app SHALL evaluate camera communication (C002), shielding gas (A001), and lens heavy contamination (L001) laser-enable guards **before** sending laser-on Modbus commands.

For each alarm type:

- When the corresponding dangerous-operations toggle is **OFF** and the alarm is **active**, laser enable MUST be blocked and the operator MUST see the corresponding warn dialog again on that attempt (immediate warn queue, same copy as passive alarms).
- When the corresponding toggle is **ON** and the alarm is still active, that alarm MUST NOT block laser enable and MUST NOT enqueue a repeat warn dialog solely because of that alarm on that attempt.
- Laser **disable** / end-of-work actions MUST NOT be blocked by these guards.
- While laser enable is active in Quick Mode or Engineer Mode, when a guarded alarm is active and the matching bypass toggle is **OFF**, the app MUST force laser enable off (runtime work guard) without blocking laser disable.

Laser-enable C002 blocking MUST use an active warn dialog path that is not suppressed by passive warn-cache reminder consumption. Blocking MUST occur even when dialog materialization returns null.

All `WARN_TYPE` warn dialogs shown through the global warn dialog pipeline (including immediate laser-enable blocks) MUST play the warn alarm sound when displayed.

Quick Mode laser enable SHALL run the same laser-power vs advanced-settings start/end power validation as Engineer Mode before `EngineerModeCheck.enableLaser`.

Active predicates:

| Alarm | Active when |
|-------|-------------|
| Camera C002 | Camera ping health reports unreachable (`CameraCommStatus.isFault()`) |
| Gas A001 | `ShieldingGasAlarmMessageUtil.hasActiveAlarm(deviceStatus)` |
| Lens L001 | A production heavy contamination episode is unresolved (pending reminder after detect, or acknowledged this boot without a level-0 / fault-cleared event) |

#### Scenario: Camera fault blocks laser enable by default

- **WHEN** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **AND** the operator taps laser enable in Quick Mode or Engineer Mode
- **THEN** laser enable MUST NOT proceed
- **AND** the operator MUST see the C002 camera communication warn dialog

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
- **AND** the operator MUST see the A001 shielding gas warn dialog

#### Scenario: Gas bypass allows laser enable

- **WHEN** shielding gas alarm A001 is active
- **AND** `allowWorkAfterGasAlarm` is true
- **AND** all other laser-enable preflight checks pass
- **THEN** laser enable MAY proceed
- **AND** the app MUST NOT show a repeat A001 popup solely for that laser-enable attempt

#### Scenario: Lens contamination blocks repeat laser enable by default

- **WHEN** a production heavy lens contamination episode is unresolved (L001)
- **AND** `allowWorkAfterLensContamination` is false
- **AND** the operator taps laser enable after previously acknowledging the post-laser-stop L001 dialog
- **THEN** laser enable MUST NOT proceed
- **AND** the operator MUST see the L001 heavy contamination warn dialog again

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
- **THEN** the app MUST force laser enable off
- **AND** laser disable MUST NOT be blocked by dangerous guards

#### Scenario: C002 laser-enable block plays warn sound

- **WHEN** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **AND** the operator taps laser enable
- **THEN** laser enable MUST NOT proceed
- **AND** the C002 warn dialog MUST be shown with warn alarm sound

#### Scenario: Quick Mode validates laser power before enable

- **WHEN** the operator taps laser enable in Quick Mode
- **AND** process laser power does not exceed advanced-settings start or end power thresholds
- **THEN** laser enable MUST NOT proceed
- **AND** the app MUST show the existing laser power validation message

### Requirement: Dangerous operations settings are app-only

The three dangerous-operations boolean fields MUST be read by the Advanced Settings UI and laser-enable guard only. They MUST NOT be included in Advanced Settings Modbus write payloads or remote stat / device.online snapshots.

#### Scenario: Modbus payload omits dangerous operations toggles

- **WHEN** the app builds an Advanced Settings Modbus write payload
- **THEN** the payload MUST NOT include `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, or `allowWorkAfterLensContamination`

#### Scenario: Remote snapshot omits dangerous operations toggles

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** dangerous-operations toggle fields MUST NOT appear in the remote snapshot JSON
