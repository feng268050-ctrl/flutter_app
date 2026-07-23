## Why

The tablet RGB indicator lights (red / yellow / green) currently follow an outdated mapping that does not match operator-facing semantics for laser online, standby, emitting, alarm, and ready states. Aligning GPIO behavior with the product brief reduces confusion on the shop floor.

## Operator semantics (product brief)

| LED | Role | Off | Blink (1 Hz) | Steady on |
|-----|------|-----|--------------|-----------|
| **Red** | Laser indicator | Laser not powered on or not connected (`isLaserCommunicationAlarm`) | Laser online, standby (communicating, not emitting) | Laser emitting (`isLaserOn`) |
| **Yellow** | Alarm indicator | No system alarm | Alarm present | — |
| **Green** | Ready indicator | Not ready | — | Ready to emit (all interlocks + Laser Enable, not emitting) |

## What Changes

- **Red LED**: off when laser communication alarm; 1 Hz blink when laser is online/standby (`!isLaserCommunicationAlarm()` and `!isLaserOn()`); steady on when emitting.
- **Yellow LED**: 1 Hz blink when any Modbus hardware alarm segment is active; off when no alarms.
- **Green LED**: steady on only when **ready** — all of safety ground lock conducting, key switch on, air/vent on, Laser Enable on, no emit, no hardware alarm; off otherwise.
- **Unify flash timing** in `GpioLedManager` to 500 ms on / 500 ms off (1 Hz).
- **Centralize LED decisions** in `GpioLedHandler`; laser-enable UI changes trigger immediate `refresh()`.

## Capabilities

### New Capabilities

- `rgb-gpio-indicator-lights`: Operator semantics, signal sources, red/yellow/green GPIO rules, flash cadence, and refresh triggers.

### Modified Capabilities

- `modbus-poll-scheduler`: `finishPollCycle` remains the primary Modbus-driven LED update path; laser-enable UI changes SHALL also trigger `GpioLedHandler.refresh()`.

## Impact

- `RgbLedDecision`, `GpioLedHandler`, `GpioLedManager`
- `DeviceStatus.hasAnyHardwareAlarm()`, `LaserEnableStateHolder`
- Quick Mode / Engineer Mode laser-enable callbacks
- Unit tests for LED predicates
