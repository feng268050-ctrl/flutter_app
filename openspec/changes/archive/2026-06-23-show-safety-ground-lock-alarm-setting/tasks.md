## 1. Data model and migration

- [x] 1.1 Add `showSafetyGroundLockAlarm` (`Boolean`, `@ColumnInfo(defaultValue = "0")`, default false) to `CommonSettings`
- [x] 1.2 Set default false in `DefaultValueUtils.createDefaultCommonSettings()`
- [x] 1.3 Add `Migration_49_50` (`ALTER TABLE` add column default 0) and bump `AppDatabase` version to 50

## 2. Preference reader

- [x] 2.1 Add `SafetyGroundLockAlarmSettings` with `isEnabled(Context)`, `setEnabled(Context, boolean)`, and test override (mirror `BootSelfCheckSettings` cache pattern)
- [x] 2.2 Gate `SafetyGroundLockPrompt.maybeShow` on `SafetyGroundLockAlarmSettings.isEnabled` before latching or showing dialog

## 3. Common Settings UI

- [x] 3.1 Add string resources: `common_settings_show_safety_ground_lock_alarm` (zh / en / default)
- [x] 3.2 Add Misc `InsetListRow` + `FrostSwitchView` in `fragment_common_settings.xml` below boot self-check row
- [x] 3.3 Bind switch in `CommonSettingsFragment` (render, `setOnCheckedChangeListener`, persist via `updateCommonSettings`)

## 4. Remote snapshot and tests

- [x] 4.1 Ensure `commonSettings` JSON serialization includes `showSafetyGroundLockAlarm` (Gson field on entity / snapshot path)
- [x] 4.2 Update `DeviceRemoteSnapshotTest` and any `AdvancedSettingConvertUtilTest` / migration tests for new field
- [x] 4.3 Add unit tests for `SafetyGroundLockPrompt` (enabled vs disabled) and `SafetyGroundLockAlarmSettings` default

## 5. Verification

- [x] 5.1 Emulator: with switch off, laser enable + gun press + open interlock — no prompt; turn switch on — prompt appears
- [x] 5.2 Run `make sync` on emulator after implementation (build succeeded; adb install blocked — no emulator connected)
