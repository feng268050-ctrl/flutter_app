## Why

Production laser-on AI features (lens contamination detection via `OpencvStainDetectCoordinator` and zero-point offset detection via `ZeroPointDetectCoordinator`) currently run unconditionally whenever the device is in eligible weld scope. Operators need explicit control over whether these assistive detections run during welding, without disabling the underlying AI stack or post-laser alerts infrastructure.

## What Changes

- Add a new **AI Assistance** group on the Advanced Settings page with two toggle switches:
  - **Lens Contamination Detection** — controls live-weld stain detect sampling and heavy-contamination alert pending during laser-on sessions
  - **Zero Point Offset Detection** — controls laser-on zero-point detect rounds, correction writes, and offset alert pending
- Both toggles default to **ON** (enabled) on fresh install and after migration for existing devices
- Persist toggle state in `t_advanced_settings` as app-only Advanced Settings fields (not mapped to Modbus registers)
- Gate production coordinators at laser-on / sampling entry points so disabled features skip inference, pending alerts, and Modbus correction for that session
- Add localized EN/ZH strings for the group title and toggle labels
- Update `advanced-settings-persistence` to document that `t_advanced_settings` may hold both Modbus-backed parameters and app-only Advanced Settings fields

## Capabilities

### New Capabilities

- `advanced-settings-ai-assistance`: Advanced Settings UI group, persistence fields, defaults, and coordinator gating for lens contamination and zero-point offset detection toggles

### Modified Capabilities

- `settings-page-structure`: Advanced Settings gains a fourth titled group **AI Assistance** with the two toggles
- `advanced-settings-persistence`: `t_advanced_settings` gains `lensContaminationDetectionEnabled` and `zeroPointOffsetDetectionEnabled`; clarify app-only vs Modbus-backed columns
- `production-lens-det-dirty-alerts`: Heavy stain detect and alert pending SHALL be skipped when lens contamination detection is disabled
- `production-zero-point-offset-alerts`: Offset alert pending SHALL be skipped when zero-point offset detection is disabled
- `zero-point-detect-on-laser-on`: Laser-on zero-point rounds SHALL NOT start or sample when zero-point offset detection is disabled

## Impact

- **UI**: `fragment_advanced_setting.xml`, `AdvancedSettingFragment`, strings (`values` / `values-zh`)
- **Data**: `AdvancedSettings` entity, Room migration, `AdvancedSettingsDao`, `AdvancedSettingViewModel`, cached reader for coordinators
- **Runtime**: `OpencvStainDetectCoordinator`, `ZeroPointDetectCoordinator`, `ModbusFiledBuilder` (ensure toggles excluded from device write payload)
- **Tests**: Unit tests for coordinator gating when toggles off; migration default tests if present
