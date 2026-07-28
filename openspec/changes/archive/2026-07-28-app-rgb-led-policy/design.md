## Context

`linux-gpio-rgb-led` already covers pin labels and Steady/Blink/Off. Production policy (when each mode applies) was deferred from P2 and later implemented in the Flutter App as `RgbLedPolicyDriver` + `RgbLedDecision`, mirroring lws-ui `GpioLedHandler` / `RgbLedDecision` / `LaserEnableStateHolder`. Blink regressions (poll refresh restarting blink → looks steady; skipped first Off leaving boot HIGH) required App/HAL idempotency and forced reset.

## Goals / Non-Goals

**Goals:**

- Spec the operator-visible red/yellow/green rules for lws-hmi.
- Spec lifecycle: start after warn-alarm, forced Off before first policy apply, LED Settings override + Off on enter.
- Spec green inputs from work-screen Laser Enable holder + UI process wire value (CNC = 5).
- Spec yellow: non-bypassable / hardware codes always blink; C002/L001/W* follow allow-*; A001 always yellow while active even if dialog INFO.

**Non-Goals:**

- Changing GPIO pin numbers or `gpio.json` paths.
- Music-reactive / experimental PWM (lws-ui only).
- Android YNHAPI backend.
- Soft-interrupt laser / alarm dialog copy (separate capabilities).

## Decisions

### D1 — App owns policy; HAL owns blink ticks

**Choice:** Pure decision in App (`RgbLedDecision`); GPIO mode apply via `GpioLedController` → `cyber_hal` `GpioLine.setMode`. Blink timers live in HAL.

**Why:** Matches dart-hal split (product LEDs not portable HAL policy). Keeps emulator overlay listening to HAL level events.

**Alternative:** App-side Timer blink — rejected (duplicate with HAL, overlay would desync).

### D2 — Laser Enable from session holder, not Modbus alone

**Choice:** `LaserEnableLedHolder` mirrors lws-ui `LaserEnableStateHolder`: Quick/Engineer sync enable + `ProcessType.wireValue` (CNC Cut = 5). Policy does not watch `control.laser_enable` / `control.process_type` for green.

**Why:** Modbus process_type uses CNC = 4; UI wire value is 5. Enable is a work-screen session concept.

### D3 — Same-mode skip + forced Off

**Choice:** Skip re-applying identical mode so Modbus/alarm refresh does not restart blink. `resetAllOff()` / `setMode(..., force: true)` at policy `start` and LED Settings enter so boot or leftover HIGH is cleared.

**Why:** Poll cadence < 1 s made blink look steady; software default Off skipped first hardware Off write.

### D4 — Yellow vs green bypass asymmetry for A001

**Choice:** A001 always contributes to yellow blink while fault-active; green ready block still honors `allowWorkAfterGasAlarm`.

**Why:** lws-ui treats control-card gas bits as non-feeder hardware for yellow while dialog may be INFO under gas bypass.

### D5 — Manual override only on LED Settings

**Choice:** `beginManualOverride` / `endManualOverride` around the settings page; production policy otherwise global after warn-alarm `start`.

## Risks / Trade-offs

- [Boot leaves pins HIGH before warn.start] → Mitigation: `resetAllOff` at policy start; Settings also resets.
- [Holder stale after abnormal leave] → Mitigation: page `clear` / controller `clearLaserEnable` on dispose.
- [Spec drift vs lws-ui] → Mitigation: scenarios keyed to attribute ids (`machine.laser_on`, `alarm.laser_comm`, …) and holder wire values.

## Migration Plan

- Docs/spec only for this change folder; code already on `main`.
- Archive promotes `rgb-gpio-indicator-lights` into `openspec/specs/` and merges deltas.

## Open Questions

- None for archive; further tuning (e.g. active_low per board) stays under `hal-gpio-config` / product `gpio.json`.
