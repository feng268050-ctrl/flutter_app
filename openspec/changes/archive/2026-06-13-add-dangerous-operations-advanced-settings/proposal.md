## Why

Operators sometimes need to continue welding after non-fatal safety advisories (camera communication fault, shielding-gas path alarm, or heavy protective-lens contamination) when they accept the risk. Today the app blocks laser enable and re-surfaces those alarms with no operator-controlled override. Advanced Settings needs an explicit **Dangerous Operations** group so trained users can suppress repeat blocking popups and force laser enable while the underlying fault persists.

## What Changes

- Add a **Dangerous Operations** group on the Advanced Settings page with three Switch controls (all default **OFF**):
  - **Allow Work after Camera Alarm** — bypass C002 laser-enable blocking and suppress repeat camera-comm popup on laser-enable attempts while ping fault persists
  - **Allow Work after Gas Alarm** — bypass A001 laser-enable blocking and suppress repeat shielding-gas popup on laser-enable attempts while gas alarm persists
  - **Allow Work after Lens Contamination** — bypass L001 laser-enable blocking and suppress repeat heavy-contamination popup on laser-enable attempts while contamination episode persists
- Persist the three toggles in `t_advanced_settings` as app-only fields (not Modbus-backed)
- Extend laser-enable preflight (`EngineerModeCheck.enableLaser` path used by Quick Mode and Engineer Mode) so camera, gas, and lens contamination alarms **block laser enable by default** and **re-show the corresponding alarm dialog** on each attempt
- When the matching dangerous-operations toggle is ON, skip that alarm's laser-enable block and do not enqueue a repeat popup for that attempt; laser enable proceeds through the normal reminder/Modbus path
- Add localized EN/ZH strings for the group title, toggle labels, and per-toggle hint lines
- Unit tests for preflight gating, bypass behavior, persistence defaults, and migration

**Bundled fixes shipped with this change (same release):**

- **Runtime work guard (`LaserWorkGuard`)**: while laser enable is active in Quick/Engineer mode, force laser off when C002/A001/L001 is active and the matching bypass toggle is OFF
- **C002 laser-enable dialog**: use an active block dialog that is not suppressed by passive warn-cache reminder state; block even when dialog VO is null
- **Warn alarm sound**: all `WARN_TYPE` warn dialogs (including immediate laser-enable blocks and passive C002) play `GlobalSoundManager.warnSound()` when shown
- **Dangerous Operations toggle hints**: secondary hint text under each of the three switches (EN/ZH)
- **Quick Mode laser power preflight**: `EngineerDataCheck.checkLaserPower` before laser enable (same rule as Engineer Mode)
- **Engineer welding UI copy**: continuous/point welding fields use **Laser Power** label and matching validation toasts (aligned with cut/clean)
- **Laser power vs termination power toast**: fix misleading “less than termination power” copy to match validation (`laserPower` must exceed `laserEndPower`)

## Capabilities

### New Capabilities

- `advanced-settings-dangerous-operations`: Advanced Settings UI group, persistence fields, defaults, cached reader, and laser-enable alarm guard / bypass semantics for camera (C002), gas (A001), and lens heavy contamination (L001)

### Modified Capabilities

- `settings-page-structure`: Advanced Settings gains a fifth titled group **Dangerous Operations** with the three toggles below AI Assistance
- `advanced-settings-persistence`: `t_advanced_settings` gains three app-only boolean columns for dangerous-operations overrides; document defaults OFF
- `laser-enable-emulator-preflight`: Laser-enable preflight SHALL evaluate camera and lens contamination guards in addition to existing gas / Modbus checks, with dangerous-operations bypass when toggles are ON
- `production-lens-det-dirty-alerts`: After a heavy contamination episode, laser enable SHALL be blocked until contamination clears or **Allow Work after Lens Contamination** is ON

## Impact

- **UI**: `fragment_advanced_setting.xml`, `AdvancedSettingFragment`, `AdvancedSettingVo`, strings (`values` / `values-zh`)
- **Data**: `AdvancedSettings` entity, Room migration, `AdvancedSettingsDao`, `AdvancedSettingViewModel`, `AdvancedSettingConvertUtil`, `DefaultValueUtils`
- **Runtime**: `EngineerModeCheck`, `DeviceDialogHandler` / `DeviceStatusConvert` (laser-enable active detection path), `CameraCommunicationWarnAlarm`, `ShieldingGasAlarmMessageUtil`, `LensHeavyContaminationWarnAlarm`, new `DangerousOperationsSettings` cache reader
- **Tests**: Preflight block/bypass tests per alarm; migration default tests; settings cache tests
