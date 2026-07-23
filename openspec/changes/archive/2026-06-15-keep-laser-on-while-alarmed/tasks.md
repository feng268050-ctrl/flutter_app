## 1. Data model and persistence

- [x] 1.1 Add `keepLaserOnWhileAlarmed` to `AdvancedSettings`, `AdvancedSettingVo`, and `AdvancedSettingConvertUtil` (default false)
- [x] 1.2 Add Room migration 48→49 with `@ColumnInfo(defaultValue = "0")`; bump `AppDatabase` version; update `DefaultValueUtils.createDefaultAdvancedSettings()`

## 2. Cached settings reader

- [x] 2.1 Extend `DangerousOperationsSettings` with `isKeepLaserOnWhileAlarmed`, setter, cache refresh, and test override
- [x] 2.2 When toggled OFF, call `LaserWorkGuard.evaluateAndInterruptIfNeeded` (mirror per-alarm bypass behavior)

## 3. Advanced Settings UI

- [x] 3.1 Add EN/ZH strings for **Keep Laser On while Alarmed** label and hint (first row in Dangerous Operations)
- [x] 3.2 Insert switch row at top of Dangerous Operations group in `fragment_advanced_setting.xml` (before camera-alarm row)
- [x] 3.3 Wire switch in `AdvancedSettingFragment` / `AdvancedSettingViewModel` with suppress-callback guard and persist via `DangerousOperationsSettings`

## 4. Runtime laser interrupt guard

- [x] 4.1 Short-circuit `LaserEnableAlarmGuard.isWorkBlocked` to return false when `keepLaserOnWhileAlarmed` is ON
- [x] 4.2 Confirm `passesPreflight` is unchanged (no keep-laser-on bypass on laser-enable attempts)
- [x] 4.3 Verify Quick Mode and Engineer Mode `deviceStatusListen` paths respect the new bypass via `isWorkBlocked`

## 5. Exclusions

- [x] 5.1 Confirm Modbus write payload and remote stat snapshot builders exclude `keepLaserOnWhileAlarmed`

## 6. Tests

- [x] 6.1 Migration test: version 48→49 adds `keepLaserOnWhileAlarmed` default false
- [x] 6.2 `DangerousOperationsSettings` cache/default tests for new field
- [x] 6.3 `LaserEnableAlarmGuard` / `LaserWorkGuard` tests: E006 (or other non-trio code) forces laser off by default; no interrupt when toggle ON; interrupt restored when toggle turned OFF

## 7. Verification

- [x] 7.1 Run unit tests for migration, settings cache, and alarm guard
- [x] 7.2 `make sync` and manually verify Advanced Settings row order and runtime behavior on emulator
