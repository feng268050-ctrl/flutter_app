## 1. Data model and migration

- [x] 1.1 Add `CommonSettings` entity (`t_common_settings`) with fields `language`, `unit`, `soundEffect`, `showBootSelfCheck`
- [x] 1.2 Add `ParameterSettings` entity (`t_parameter_settings`) with all device-parameter columns from legacy `AdvancedSetting`
- [x] 1.3 Add `UnitSystem` enum (`imperial`, `metric`) and ISO language constants (`zh-CN`, `en-US`)
- [x] 1.4 Add `CommonSettingsDao` and `ParameterSettingsDao` with singleton `selectOne` / `insert` / `update` (+ `selectOneLiveData` for common settings)
- [x] 1.5 Bump `AppDatabase` version and implement Migration 43→44: create tables, copy split data from `t_advanced_setting`, drop legacy table
- [x] 1.6 Register new entities/DAOs in `AppDatabase`; remove `AdvancedSetting` / `AdvancedSettingDao` (or deprecate after call-site migration)
- [x] 1.7 Add migration unit test covering legacy row → both tables (language/unit/voiceCheck/showBootSelfCheck mapping)

## 2. Defaults and conversion layer

- [x] 2.1 Split `DefaultValueUtils.createDefaultAdvancedSetting()` into `createDefaultCommonSettings()` and `createDefaultParameterSettings()`
- [x] 2.2 Update `AdvancedSettingConvertUtil` (or replace) to merge/split `CommonSettings` + `ParameterSettings` ↔ `AdvancedSettingVo` for unchanged UI binding
- [x] 2.3 Map `unit` enum ↔ legacy boolean in `TemperatureUnitConvertUtil` call sites via thin adapter helpers

## 3. ViewModel and settings module

- [x] 3.1 Refactor `AdvancedSettingViewModel` to read/write both DAOs; keep public `AdvancedSettingVo` API for Fragment
- [x] 3.2 Update `AdvancedSettingFragment` persistence paths: language → `zh-CN`/`en-US`, unit → enum, soundEffect, showBootSelfCheck (UI controls unchanged)
- [x] 3.3 Update `BootSelfCheckSettings` to use `t_common_settings` as source of truth (remove duplicate store if any)
- [x] 3.4 Update `GlobalSoundManager` / sound effect reads to use `CommonSettingsDao` instead of `voiceCheck` on advanced table
- [x] 3.5 Raise `blowPressureThreshold` validation max to 500 in `AdvancedSettingDataCheck` and related UI limits/strings

## 4. Downstream consumers

- [x] 4.1 Update `QuickProcessParametersDataViewModel` and other `AdvancedSettingDao` / `unitSetting` observers to `CommonSettingsDao`
- [x] 4.2 Update engineer/quick mode Modbus write paths to load parameters from `ParameterSettingsDao`
- [x] 4.3 Update `ModbusFiledBuilder.doCreateWriteDeviceSetting` input type to `ParameterSettings` (or adapter)
- [x] 4.4 Wire `WarnInfoFragment` to `CommonSettings.unit`; convert Alarm Information temperature display via `TemperatureUnitConvertUtil` (display only, alarm bindings unchanged)
- [x] 4.5 Extend `DeviceData` temperature `*Text` methods (or binding adapter) to accept unit and format `℃` / `°F` with one decimal where applicable

## 5. Remote snapshot and WebSocket

- [x] 5.1 Add `CommonSettings` (or snapshot DTO) for wire serialization; remove `advancedSettings` from `DeviceRemoteSnapshot` and `DeviceInfoVo`
- [x] 5.2 Update `DeviceStatusPut` to populate `commonSettings` from `CommonSettingsDao` only
- [x] 5.3 Update tests (`DeviceWebSocketConnectionTest`, snapshot JSON tests) to assert `commonSettings` present and `advancedSettings` absent
- [x] 5.4 Update `docs/network-api-reference.md` and any WS docs referencing `advancedSettings`

## 6. Verification

- [x] 6.1 Manual: Advanced Settings page — edit language, unit, sound, boot self-check, and each device parameter; confirm persistence across restart
- [x] 6.2 Manual: Modbus write still includes 0x0090–0x009F after parameter edit
- [x] 6.3 Manual: `command.stat_response` / `device.online` JSON shows `commonSettings` only (no `advancedSettings`)
- [x] 6.4 Manual: Alarm Information — switch unit metric/imperial; confirm temperature tiles update; alarm indicators unchanged
- [x] 6.5 Run unit tests and fix regressions
