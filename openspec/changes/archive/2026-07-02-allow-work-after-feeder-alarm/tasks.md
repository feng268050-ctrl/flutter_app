## 1. Persistence & data model

- [x] 1.1 Add `allowWorkAfterFeederAlarm` to `AdvancedSettings`, `AdvancedSettingVo`, `DefaultValueUtils`, and convert utilities
- [x] 1.2 Add Room migration 50→51 (`Migration_50_51`) and bump `AppDatabase` version; regenerate Room schema JSON
- [x] 1.3 Extend `DangerousOperationsSettings` with cache read/write/test override for `allowWorkAfterFeederAlarm`

## 2. Advanced Settings UI

- [x] 2.1 Add EN/ZH strings for toggle title and informational hint (`advanced_setting_allow_work_after_feeder_alarm`, `_hint`)
- [x] 2.2 Add switch row after lens contamination in `fragment_advanced_setting.xml`
- [x] 2.3 Wire toggle in `AdvancedSettingFragment` and `AdvancedSettingViewModel` (load, persist, suppress callback guard)

## 3. Laser-enable & runtime guards

- [x] 3.1 Add `isFeederBlocking` / `isFeederAlarmActive` helpers in `LaserEnableAlarmGuard` (toggle-only; no process-type gating)
- [x] 3.2 Integrate feeder guard into `passesPreflight`, `isWorkBlocked`, `isReadyIndicatorBlocked`, and `isBypassableAlarmCode`
- [x] 3.3 Update `WarnEpisodeController.LaserEnableAlarmGuardCompat` to include W001/W002 in bypassable code set

## 4. Tests & verification

- [x] 4.1 Unit tests: feeder blocks when toggle OFF; bypass allows laser enable and runtime work when toggle ON (all process types)
- [x] 4.2 Unit tests: `DangerousOperationsSettings` feeder toggle cache/persist; migration default false
- [x] 4.3 Run `make sync` on emulator and verify Advanced Settings UI + laser-enable behavior with mock feeder alarm
