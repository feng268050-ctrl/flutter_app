## Context

RGB indicator lights on the YNH tablet side panel are driven by `GpioLedManager` (YNHAPI `setGpioState`) and orchestrated from `GpioLedHandler` → `RgbLedDecision`, invoked at the end of each Modbus poll cycle in `RxModbusPollResults.finishPollCycle` and on explicit `GpioLedHandler.refresh()` from work-screen UI.

Side-panel LEDs are **GPIO**, not YNHAPI `Light` PWM (`LIGHT_RED` 15 / etc.). Those Light paths write `led-*-pwm` sysfs and do not drive the three side indicators on ynh960.

### ynh960 GPIO pin map (hardware-verified)

| Color | GPIO | Notes |
|-------|------|-------|
| Red | **4** | Supplier doc had 5 — invalid on 239 |
| Yellow | **3** | Supplier doc had 4 — invalid |
| Green | **6** | Supplier doc had 7 — invalid |

Configured in `GpioLedConfig`. DevActivity exposes manual GPIO test buttons (红脚 4 / 黄脚 3 / 绿脚 6).

## Operator semantics

### Red — laser indicator

| GPIO state | Device meaning |
|------------|----------------|
| **Off** | Laser communication alarm (`isLaserCommunicationAlarm`) — laser not online / not connected |
| **Blink 1 Hz** | Laser **standby** — communication OK, not emitting |
| **Steady on** | Laser **emitting** (`isLaserOn`) |

Red blink is **suppressed** while laser communication alarm is active.

### Yellow — alarm indicator

| GPIO state | Device meaning |
|------------|----------------|
| **Off** | No hardware alarm in scanned Modbus segments |
| **Blink 1 Hz** | At least one hardware alarm (`hasAnyHardwareAlarm()`) |

Yellow reflects **raw Modbus alarm segments**, independent of advanced-setting laser-enable bypass toggles.

### Green — ready indicator

| GPIO state | Device meaning |
|------------|----------------|
| **Off** | Not ready |
| **Steady on** | **Ready** — operator may proceed (mode-specific rules below) |

Green is always **off** when:

- Laser is emitting (`isLaserOn()`)
- **Ready is blocked by coded alarms** — `LaserEnableAlarmGuard.isReadyIndicatorBlocked()` (aligns with advanced-setting bypass for A001 / C002 / L001 only; does **not** use `keepLaserOnWhileAlarmed`)
- Key switch is off (`!isKeySwitchOn()`)

#### Standard work modes (Quick / Engineer — not CNC Cut)

**Steady on** when **all** of:

- Laser Enable active — `LaserEnableStateHolder.isActive()`
- Safety ground lock conducting — `isSafetyGroundLockLocked()`
- Key switch on — `isKeySwitchOn()`
- Plus the global off conditions above

**Not required:** ventilation / air valve (`isAirValveOn()`).

#### CNC Cut (Quick Mode only)

CNC has **no Laser Enable** button. Connection is detected by `CNCCutFragment` watching Modbus `DeviceStatus.isConnectCNC()` (`machineStatusSeg1` bit 10) — same signal as `communicationStatus == 2` in the CNC UI.

**Steady on** when **all** of:

- Active work model is `ModelConstant.CNC_CUT` — `LaserEnableStateHolder.getActiveWorkModel()`
- `DeviceStatus.isConnectCNC()` is true
- Key switch on — `isKeySwitchOn()`
- Plus the global off conditions above

**Not used for CNC green:** `cncOpening` overlay flag, Laser Enable, safety ground lock.

## Signal sources

| Signal | API |
|--------|-----|
| Laser emitting | `DeviceStatus.isLaserOn()` |
| Laser communication / offline | `DeviceStatus.isLaserCommunicationAlarm()` |
| Hardware alarms (yellow) | `DeviceStatus.hasAnyHardwareAlarm()` |
| Green ready block (coded alarms) | `LaserEnableAlarmGuard.isReadyIndicatorBlocked(context, deviceStatus)` |
| CNC connected | `DeviceStatus.isConnectCNC()` |
| Standard ready interlocks | `isSafetyGroundLockLocked()`, `isKeySwitchOn()`, `LaserEnableStateHolder` |
| Active work model | `LaserEnableStateHolder.getActiveWorkModel()` |

## Decisions

### Red mode priority

1. `isLaserOn()` → steady on
2. `isLaserCommunicationAlarm()` → **off** (not blink)
3. Else → blink 1 Hz (standby)

### Green — mode split

- **CNC Cut:** `workModel == CNC_CUT` ∧ `isConnectCNC()` ∧ key on ∧ global gates
- **Other modes:** `laserEnableActive` ∧ safety ground lock ∧ key on ∧ global gates

### Laser Enable holder

`LaserEnableStateHolder` tracks laser-enable and active work model. Updated on successful Laser Enable Modbus writes and when switching Quick/Engineer/CNC fragments. `clearLaserEnable()` on `GeneralOperationsFragment` teardown clears laser-enable **only** (does not reset work model). Full `clear()` on Engineer activity destroy.

### Dev / manual test

`GpioLedHandler.setAutoRefreshPaused(true)` while DevActivity is foreground; `suspendForManualControl()` on `GpioLedManager` for raw GPIO buttons. Business rules resume on leave.

### Flash cadence

`LED_FLASH_ON_MS = 500`, `LED_FLASH_OFF_MS = 500` for red standby and yellow alarm.

## Risks / Trade-offs

- **[Risk]** Laser comm alarm and yellow blink coincide — intentional: yellow shows fault, red stays off (not standby).
- **[Risk]** `machineStatusSeg1` bit 10 (`isConnectCNC`) is undocumented in monitor-field-mapping (bits 9–15 marked reserved); verified on ynh960 hardware.
- **[Trade-off]** Poll latency up to ~100 ms before LED updates — acceptable; `refresh()` on laser-enable, CNC connect, and advanced-setting toggles covers UI path.
