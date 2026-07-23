## ADDED Requirements

### Requirement: Common settings persisted in dedicated table

The app SHALL persist user-facing general preferences in Room table `t_common_settings` via entity `CommonSettings`. The table SHALL hold at most one application-active row; readers MUST use the same singleton selection pattern as the legacy `t_advanced_setting` table (`ORDER BY id DESC LIMIT 1` or equivalent).

The row SHALL include:

| Field | Type | Semantics |
|-------|------|-----------|
| `language` | `TEXT` | ISO 639 language tag with region, e.g. `zh-CN`, `en-US` |
| `unit` | `TEXT` | Unit system enum: `imperial` or `metric` |
| `soundEffect` | `INTEGER` | Selected UI click sound effect index (same value domain as legacy `voiceCheck`) |
| `showBootSelfCheck` | `INTEGER` (boolean) | Whether to show boot self-check on first home entry |

#### Scenario: Fresh install defaults

- **WHEN** no row exists in `t_common_settings` on first access
- **THEN** the app MUST insert a default row with `language` `en-US`, `unit` `metric`, `soundEffect` `0`, and `showBootSelfCheck` true

#### Scenario: Language change persists ISO tag

- **WHEN** the user selects Chinese or English on the Advanced Settings page
- **THEN** the app MUST persist `language` as `zh-CN` or `en-US` respectively in `t_common_settings`

#### Scenario: Unit change persists enum string

- **WHEN** the user selects metric or imperial on the Advanced Settings page
- **THEN** the app MUST persist `unit` as `metric` or `imperial` respectively in `t_common_settings`

### Requirement: Legacy advanced-setting preference columns migrate to common settings

On database upgrade, when legacy table `t_advanced_setting` contains a row, the migration SHALL copy preference fields into `t_common_settings` using these mappings:

- `languageSetting` `zh` or `zh-CN` → `language` `zh-CN`; `en`, `en-US`, null, or other → `language` `en-US`
- `unitSetting` `false` → `unit` `imperial`; `true` or null → `unit` `metric`
- `voiceCheck` → `soundEffect` (same integer value)
- `showBootSelfCheck` → `showBootSelfCheck` (same boolean)

#### Scenario: Existing device upgrades with Chinese and imperial

- **WHEN** legacy row has `languageSetting` `zh`, `unitSetting` false, `voiceCheck` 2, `showBootSelfCheck` false
- **THEN** migrated `t_common_settings` MUST have `language` `zh-CN`, `unit` `imperial`, `soundEffect` 2, `showBootSelfCheck` false

### Requirement: Remote snapshot exposes commonSettings only for preferences

The transport-neutral remote snapshot (`command.stat_response` `payload.data` and `device.online` `payload.stat`) SHALL include object field `commonSettings` sourced from `t_common_settings` at serialization time.

The JSON object MUST contain exactly these camelCase properties:

- `language` (string)
- `unit` (string, `imperial` or `metric`)
- `soundEffect` (number)
- `showBootSelfCheck` (boolean)

The snapshot MUST NOT include legacy root field `advancedSettings`.

#### Scenario: Stat response carries common settings

- **WHEN** `t_common_settings` has `language` `zh-CN`, `unit` `metric`, `soundEffect` 1, `showBootSelfCheck` true
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.commonSettings` MUST equal `{"language":"zh-CN","unit":"metric","soundEffect":1,"showBootSelfCheck":true}` (field order not significant)

#### Scenario: Device online matches stat_response commonSettings

- **WHEN** the device sends `device.online` with `payload.stat`
- **THEN** `payload.stat.commonSettings` MUST deep-equal `payload.data.commonSettings` from a contemporaneous `command.stat_response` built in the same process

#### Scenario: Advanced settings root field absent

- **WHEN** the device sends `command.stat_response` or `device.online`
- **THEN** the remote snapshot JSON MUST NOT contain property `advancedSettings` at the snapshot root
