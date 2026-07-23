## Why

During Quick Mode or Engineer Mode welding, any coded alarm currently forces laser enable off immediately via the runtime work guard. Trained operators sometimes need to finish a short weld segment when a non-critical alarm appears and they accept the risk. Advanced Settings already exposes per-alarm bypass toggles for camera, gas, and lens contamination, but there is no operator-controlled override for **runtime laser interrupt** across all alarm types while laser is already on.

## What Changes

- Add **Keep Laser On while Alarmed** as the **first** Switch in the Advanced Settings **Dangerous Operations** group (default **OFF**)
- When **OFF** (default): existing behavior — coded alarms during active laser emission force laser enable off via `LaserWorkGuard` / `deviceStatusListen` (subject to existing A001/C002/L001 per-alarm bypass toggles)
- When **ON**: while laser enable is active, coded alarms SHALL still surface warn dialogs but SHALL **NOT** force laser enable off at runtime
- Persist the toggle in `t_advanced_settings` as an app-only boolean (`keepLaserOnWhileAlarmed`, default false); no Modbus write
- Add localized EN/ZH label and hint strings
- Unit tests for persistence default, cache reader, runtime guard bypass, and migration

Laser-enable **preflight** blocking (before turning laser on) is unchanged: operators still cannot start laser enable while blocked alarms are active unless the existing per-alarm dangerous-operations bypass applies.

## Capabilities

### New Capabilities

<!-- None — extends existing dangerous-operations and alarm-interrupt specs -->

### Modified Capabilities

- `advanced-settings-dangerous-operations`: Dangerous Operations group gains a fourth toggle **Keep Laser On while Alarmed** as the first row; documents runtime interrupt bypass semantics
- `advanced-settings-persistence`: `t_advanced_settings` gains `keepLaserOnWhileAlarmed` app-only column default false
- `settings-page-structure`: Dangerous Operations group lists Keep Laser On while Alarmed first, then the three existing allow-work toggles
- `alarm-laser-interrupt`: Runtime laser interrupt SHALL be suppressed while `keepLaserOnWhileAlarmed` is ON; warn dialogs still show

## Impact

- **UI**: `fragment_advanced_setting.xml`, `AdvancedSettingFragment`, strings (`values` / `values-en` / `values-zh`)
- **Data**: `AdvancedSettings` entity, Room migration 48→49, `DefaultValueUtils`, `AdvancedSettingViewModel`
- **Runtime**: `DangerousOperationsSettings`, `LaserEnableAlarmGuard.isWorkBlocked`, `LaserWorkGuard`, Quick Mode / Engineer Mode `deviceStatusListen` paths
- **Tests**: migration default, settings cache, `LaserEnableAlarmGuard` / `LaserWorkGuard` bypass when toggle ON
