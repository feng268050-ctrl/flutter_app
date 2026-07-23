## 1. Helpers and state

- [x] 1.1 Add `DeviceStatus.hasAnyHardwareAlarm()` consolidating gun/laser/wireFeeder/controlCard alarm segment checks used by yellow LED
- [x] 1.2 Add `LaserEnableStateHolder` updated on successful Laser Enable Modbus writes and work-model switches; `clearLaserEnable()` on GeneralOperations teardown (do not wipe work model)
- [x] 1.3 Add `RgbLedDecision` predicates for red/yellow/green desired mode

## 2. GPIO manager cadence

- [x] 2.1 Introduce shared `LED_FLASH_ON_MS` / `LED_FLASH_OFF_MS` (500/500) in `GpioLedManager`
- [x] 2.2 Apply 1 Hz timing to `redLightFlash()` and `yellowLightFlash()`; update class Javadoc

## 3. GpioLedHandler rewrite

- [x] 3.1 Red: `isLaserOn()` → steady on; `isLaserCommunicationAlarm()` → off; else standby 1 Hz blink
- [x] 3.2 Yellow: `hasAnyHardwareAlarm()` → `yellowLightFlash()`; else `yellowLightClose()`
- [x] 3.3 Green (standard modes): Laser Enable + safety ground lock + key switch + `!isLaserOn()` + `!isReadyIndicatorBlocked()` → steady on
- [x] 3.4 Green (CNC Cut): `workModel == CNC_CUT` + `isConnectCNC()` + key switch + same global gates (no Laser Enable, no safety ground lock, no `cncOpening`)
- [x] 3.5 Green ready block via `LaserEnableAlarmGuard.isReadyIndicatorBlocked()` (advanced-setting bypass for A001/C002/L001; **not** `keepLaserOnWhileAlarmed`)
- [x] 3.6 `GpioLedHandler.refresh()` from cache + holders; poll cycle via `finishPollCycle`

## 4. UI integration

- [x] 4.1 `GeneralOperationsFragment` / `EngineerModeActivity`: laser-enable callbacks call `GpioLedHandler.refresh()` (not direct `GpioLedManager`)
- [x] 4.2 `AdvancedSettingFragment`: dangerous-ops toggles (except keep-laser-on-while-alarmed) call `GpioLedHandler.refresh()`
- [x] 4.3 `CNCCutFragment` / `QuickModeActivity`: refresh LEDs on CNC connect state change; set work model on CNC fragment resume
- [x] 4.4 DevActivity: pause auto LED refresh + manual GPIO test; `GpioLedConfig` ynh960 pins 4 / 3 / 6

## 5. Tests and device verification

- [x] 5.1 Unit tests for `RgbLedDecision` and `LaserEnableAlarmGuard` ready-block (incl. CNC Cut + standard modes)
- [x] 5.2 Build and install on emulator — no startup regression
- [x] 5.3 YNH hardware (ynh960 / 192.168.0.239): GPIO side LEDs 红4/黄3/绿6; red/yellow/green business rules; CNC Cut green on `isConnectCNC()` + key switch
