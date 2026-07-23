## 1. Data model and persistence

- [x] 1.1 Add `allowWorkAfterCameraAlarm`, `allowWorkAfterGasAlarm`, and `allowWorkAfterLensContamination` to `AdvancedSettings`, `AdvancedSettingVo`, and `AdvancedSettingConvertUtil` (default false)
- [x] 1.2 Add Room migration for the three columns with `@ColumnInfo(defaultValue = "0")`; update `DefaultValueUtils.createDefaultAdvancedSettings()`
- [x] 1.3 Add `DangerousOperationsSettings` cached reader (mirror `AiAssistanceSettings`): warm cache, async persist, test overrides

## 2. Advanced Settings UI

- [x] 2.1 Add EN/ZH strings for group **Dangerous Operations** and the three toggle labels
- [x] 2.2 Add Dangerous Operations `SectionHeader` + three Switch rows to `fragment_advanced_setting.xml` after AI Assistance
- [x] 2.3 Wire switches in `AdvancedSettingFragment` / `AdvancedSettingViewModel` with suppress-callback guard and DB persist via `DangerousOperationsSettings`

## 3. Laser-enable alarm guard

- [x] 3.1 Add `LensHeavyContaminationWarnAlarm.isLaserEnableBlocked()` for unresolved L001 episode semantics
- [x] 3.2 Implement `LaserEnableAlarmGuard` (or equivalent) evaluating C002, A001, and L001 with dangerous-operations bypass per toggle
- [x] 3.3 Integrate guard into `EngineerModeCheck.enableLaser`; remove standalone gas error-dialog branch from `checkWorkStatus` so A001 uses warn dialog on laser-enable attempts
- [x] 3.4 Ensure laser disable / end-of-work paths bypass dangerous guards (Quick Mode + Engineer Mode)

## 4. Exclusions and cache refresh

- [x] 4.1 Confirm `ModbusFiledBuilder` and remote stat snapshot builders exclude the three new fields
- [x] 4.2 Refresh `DangerousOperationsSettings` cache when Advanced Settings row loads and on app start (same pattern as AI assistance)

## 5. Tests

- [x] 5.1 Migration test: existing rows get false defaults for all three dangerous-operations columns
- [x] 5.2 `DangerousOperationsSettings` cache/default tests
- [x] 5.3 Laser-enable preflight tests: each alarm blocks by default, re-shows dialog, bypass when toggle ON (C002, A001, L001)
- [x] 5.4 Lens L001 test: acknowledged episode blocks repeat enable until clean or bypass toggle

## 6. Bundled fixes (same release)

- [x] 6.1 Implement `LaserWorkGuard` runtime laser-off when guarded alarms active and bypass OFF (Quick + Engineer; C002/A001/L001 triggers)
- [x] 6.2 C002 `buildActiveBlockDialogVo` for laser-enable preflight; block when `isCameraBlocking` even if VO is null
- [x] 6.3 Play warn alarm sound for all `WARN_TYPE` dialogs in `WarnDialogUtil.openDialog`
- [x] 6.4 Add EN/ZH hint strings and layout under each Dangerous Operations toggle
- [x] 6.5 Quick Mode: `checkLaserPower` before laser enable
- [x] 6.6 Engineer welding UI: laser power label/toasts aligned with cut/clean; fix termination-power validation copy
