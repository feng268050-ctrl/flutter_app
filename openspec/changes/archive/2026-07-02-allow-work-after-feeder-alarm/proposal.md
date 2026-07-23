## Why

Wire feeder alarms (W001 communication, W002 current) currently block laser enable like any other non-bypassable coded alarm, with no operator-controlled override. Trained operators sometimes need to continue working when a feeder fault persists and they accept the risk. Advanced Settings **Dangerous Operations** already exposes per-alarm bypass toggles for camera, gas, and lens contamination; feeder alarms need the same pattern.

## What Changes

- Add a fifth Switch in Advanced Settings **Dangerous Operations**: **Allow Work after Feeder Alarm** (`allowWorkAfterFeederAlarm`, default **OFF**)
- Display localized hint text (informational only, not enforced at runtime): EN — *Continuous welding will not work properly when the wire feeder is abnormal, but other modes can continue.*; ZH — *送丝机异常时连续焊接模式将无法正常工作，但其他模式可以继续工作。*
- Persist the toggle in `t_advanced_settings` as an app-only boolean (not Modbus-backed)
- Extend `LaserEnableAlarmGuard` and runtime `LaserWorkGuard` so W001/W002 follow the same dangerous-operations bypass semantics as A001/C002/L001:
  - Toggle **OFF** → W001/W002 block laser enable and force laser off at runtime (unless `keepLaserOnWhileAlarmed` is ON)
  - Toggle **ON** → W001/W002 do not block laser enable and do not force laser off at runtime for those codes (all process types)
- Unit tests for preflight gating, bypass behavior, persistence defaults, and migration

## Capabilities

### New Capabilities

_(none — extends existing dangerous-operations capability)_

### Modified Capabilities

- `advanced-settings-dangerous-operations`: Add fifth toggle **Allow Work after Feeder Alarm** with informational hint; extend laser-enable and runtime guard semantics for W001/W002
- `advanced-settings-persistence`: `t_advanced_settings` gains `allowWorkAfterFeederAlarm` app-only column default false; exclude from Modbus payloads and remote snapshots
- `alarm-laser-interrupt`: W001/W002 support per-alarm dangerous-operations bypass when toggle ON (same as A001/C002/L001 trio)
- `settings-page-structure`: Dangerous Operations group lists five switches; feeder toggle placed after lens contamination

## Impact

- **UI**: `fragment_advanced_setting.xml`, `AdvancedSettingFragment`, `AdvancedSettingVo`, strings (`values`, `values-en`, `values-zh`)
- **Data**: `AdvancedSettings` entity, Room migration 50→51, `AdvancedSettingsDao`, `AdvancedSettingViewModel`, `AdvancedSettingConvertUtil`, `DefaultValueUtils`
- **Runtime**: `LaserEnableAlarmGuard`, `LaserWorkGuard`, `WarnEpisodeController.LaserEnableAlarmGuardCompat`, `DangerousOperationsSettings`
- **Tests**: `LaserEnableAlarmGuardTest`, `DangerousOperationsSettingsTest`, migration default test
