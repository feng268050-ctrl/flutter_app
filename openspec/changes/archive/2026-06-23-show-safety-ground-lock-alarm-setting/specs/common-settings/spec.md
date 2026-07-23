## MODIFIED Requirements

### Requirement: Common settings persisted in dedicated table

The app SHALL persist user-facing general preferences in Room table `t_common_settings` via entity `CommonSettings`. The table SHALL hold at most one application-active row; readers MUST use the same singleton selection pattern as the legacy `t_advanced_setting` table (`ORDER BY id DESC LIMIT 1` or equivalent).

The row SHALL include:

| Field | Type | Semantics |
|-------|------|-----------|
| `language` | `TEXT` | ISO 639 language tag with region, e.g. `zh-CN`, `en-US` |
| `unit` | `TEXT` | Unit system enum: `imperial` or `metric` |
| `soundEffect` | `INTEGER` | Selected UI click sound effect index (same value domain as legacy `voiceCheck`) |
| `showBootSelfCheck` | `INTEGER` (boolean) | Whether to show boot self-check on first home entry |
| `showSafetyGroundLockAlarm` | `INTEGER` (boolean) | Whether to show the safety ground lock not connected Frost prompt when laser enable is active and gun is pressed |

#### Scenario: Fresh install defaults

- **WHEN** no row exists in `t_common_settings` on first access
- **THEN** the app MUST insert a default row with `language` `en-US`, `unit` `metric`, `soundEffect` `0`, `showBootSelfCheck` true, and `showSafetyGroundLockAlarm` false

#### Scenario: Language change persists ISO tag

- **WHEN** the user selects Chinese or English on the Advanced Settings page
- **THEN** the app MUST persist `language` as `zh-CN` or `en-US` respectively in `t_common_settings`

#### Scenario: Unit change persists enum string

- **WHEN** the user selects metric or imperial on the Advanced Settings page
- **THEN** the app MUST persist `unit` as `metric` or `imperial` respectively in `t_common_settings`

### Requirement: Remote snapshot exposes commonSettings only for preferences

The transport-neutral remote snapshot (`command.stat_response` `payload.data` and `device.online` `payload.stat`) SHALL include object field `commonSettings` sourced from `t_common_settings` at serialization time.

The JSON object MUST contain exactly these camelCase properties:

- `language` (string)
- `unit` (string, `imperial` or `metric`)
- `soundEffect` (number)
- `showBootSelfCheck` (boolean)
- `showSafetyGroundLockAlarm` (boolean)

The snapshot MUST NOT include legacy root field `advancedSettings`.

#### Scenario: Stat response carries common settings

- **WHEN** `t_common_settings` has `language` `zh-CN`, `unit` `metric`, `soundEffect` 1, `showBootSelfCheck` true, and `showSafetyGroundLockAlarm` false
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.commonSettings` MUST equal `{"language":"zh-CN","unit":"metric","soundEffect":1,"showBootSelfCheck":true,"showSafetyGroundLockAlarm":false}` (field order not significant)

#### Scenario: Device online matches stat_response commonSettings

- **WHEN** the device sends `device.online` with `payload.stat`
- **THEN** `payload.stat.commonSettings` MUST deep-equal `payload.data.commonSettings` from a contemporaneous `command.stat_response` built in the same process

#### Scenario: Advanced settings root field absent

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** the remote snapshot JSON MUST NOT contain property `advancedSettings` at the snapshot root

### Requirement: Common Settings presents grouped rows

The Common Settings page SHALL present operator-facing settings in titled groups. Network MUST contain Wireless Network. Display & Sound MUST contain Language, Unit, Screen Brightness, Screen-off Time, and Sound Effect. Date & Time MUST contain Automatic, Date, Time, and Time Zone. Misc MUST contain Show Startup Self-Check and Show Safety Interlock Alarm.

#### Scenario: Network group displays wireless entry

- **WHEN** the user opens Common Settings
- **THEN** the Network group displays Wireless Network
- **AND** selecting Wireless Network opens the existing wireless network management flow

#### Scenario: Display and sound group displays preferences

- **WHEN** the user opens Common Settings
- **THEN** the Display & Sound group displays Language, Unit, Screen Brightness, Screen-off Time, and Sound Effect
- **AND** each row preserves its existing persistence or system-setting behavior

#### Scenario: Date and time group displays controls

- **WHEN** the user opens Common Settings
- **THEN** the Date & Time group displays Automatic, Date, Time, and Time Zone
- **AND** these rows preserve the Date & Time behavior defined for the app

#### Scenario: Misc group displays startup self-check

- **WHEN** the user opens Common Settings
- **THEN** the Misc group displays Show Startup Self-Check
- **AND** changing it persists to `t_common_settings.showBootSelfCheck`

#### Scenario: Misc group displays safety ground lock alarm toggle

- **WHEN** the user opens Common Settings
- **THEN** the Misc group displays Show Safety Interlock Alarm (localized label equivalent to 显示安全地锁告警)
- **AND** the switch defaults to off for a fresh install
- **AND** changing it persists to `t_common_settings.showSafetyGroundLockAlarm`

### Requirement: Common preference persistence remains in common settings

Language, Unit, Sound Effect, Show Startup Self-Check, and Show Safety Interlock Alarm SHALL remain persisted in `t_common_settings`. These values MUST NOT be persisted to `t_advanced_settings`.

#### Scenario: Language changes in Common Settings

- **WHEN** the user changes Language in Common Settings
- **THEN** the selected language is persisted in `t_common_settings.language`
- **AND** `t_advanced_settings` is not modified for that language change

#### Scenario: Unit changes in Common Settings

- **WHEN** the user changes Unit in Common Settings
- **THEN** the selected unit is persisted in `t_common_settings.unit`
- **AND** Advanced Settings temperature value boxes and scale labels refresh to the selected unit without requiring the user to leave and re-enter Advanced Settings

#### Scenario: Sound effect changes in Common Settings

- **WHEN** the user changes Sound Effect in Common Settings
- **THEN** the selected sound effect is persisted in `t_common_settings.soundEffect`
- **AND** no Modbus device setting write is sent only because the Sound Effect option changed

#### Scenario: Safety ground lock alarm toggle changes in Common Settings

- **WHEN** the user toggles Show Safety Interlock Alarm in Common Settings
- **THEN** the value is persisted in `t_common_settings.showSafetyGroundLockAlarm`
- **AND** no Modbus device setting write is sent only because that toggle changed

## ADDED Requirements

### Requirement: Database migration adds showSafetyGroundLockAlarm default false

On upgrade to the schema version that introduces `showSafetyGroundLockAlarm`, existing `t_common_settings` rows MUST receive column value false when the column is added.

#### Scenario: Existing device upgrades

- **WHEN** the app upgrades from a schema without `showSafetyGroundLockAlarm`
- **THEN** all existing `t_common_settings` rows MUST have `showSafetyGroundLockAlarm` false until the operator changes it in Common Settings
