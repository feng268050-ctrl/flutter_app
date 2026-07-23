## 1. Data model and migration

- [x] 1.1 Add `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled` (`Boolean`, default `true`) to `AdvancedSettings` entity
- [x] 1.2 Add Room migration `Migration_46_47` on `t_advanced_settings` with `ALTER TABLE` columns `DEFAULT 1`; bump `AppDatabase` version to 47
- [x] 1.3 Update `DefaultValueUtils.createDefaultAdvancedSettings()` to set both fields true
- [x] 1.4 Verify `ModbusFiledBuilder` advanced-settings write payload excludes the two new columns (no device register mapping)

## 2. Cached settings reader

- [x] 2.1 Create `AiAssistanceSettings` backed by `AdvancedSettingsDao`: cache warm, `isLensContaminationDetectionEnabled` / `isZeroPointOffsetDetectionEnabled`, async DB write on set, test overrides
- [x] 2.2 Warm `AiAssistanceSettings` cache at app startup in `LaserApplication`

## 3. Advanced Settings UI

- [x] 3.1 Add EN/ZH strings for group title **AI Assistance** and toggle labels **Lens Contamination Detection**, **Zero Point Offset Detection**
- [x] 3.2 Add AI Assistance `SectionHeader` + two Switch rows to `fragment_advanced_setting.xml` (reuse `switch_thumb` / `switch_track`)
- [x] 3.3 Expose toggle state on `AdvancedSettingVo` and load/save via `AdvancedSettingViewModel` / `t_advanced_settings`
- [x] 3.4 Wire switches in `AdvancedSettingFragment`: persist on change via DAO + refresh `AiAssistanceSettings` cache, `suppressCallbacks` guard, click sound

## 4. Production coordinator gating

- [x] 4.1 Gate `OpencvStainDetectCoordinator.onPr1I420Frame` when lens contamination detection is disabled; clear production heavy-dirty pending when disabled on laser off
- [x] 4.2 Gate `ZeroPointDetectCoordinator` round start, PR1 sampling, finalize, 0090H write, and offset alert pending when zero-point offset detection is disabled
- [x] 4.3 Ensure `EdgeDrawingDetectCoordinator` L1 Pro production path respects the zero-point toggle
- [x] 4.4 Confirm `ZeroPointManualAutoCoordinator` Manual Auto flow is NOT gated

## 5. Tests and verification

- [x] 5.1 Unit tests: coordinators skip inference/rounds when toggles off; existing behavior when toggles on
- [x] 5.2 Unit test: migration 46→47 leaves existing `t_advanced_settings` rows with both fields true
- [x] 5.3 Manual: Advanced Settings toggles persist across restart; disable each toggle and verify no live stain / zero-point activity during laser-on weld session
