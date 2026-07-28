## Why

P2 delivered GPIO Steady/Blink/Off plumbing (`linux-gpio-rgb-led`), but production chassis RGB semantics (laser standby / WARN yellow / ready green) lived only in lws-ui. lws-hmi now drives those indicators from warn-alarm + Modbus + work-screen Laser Enable; this change records that product policy as an OpenSpec capability so future work does not regress blink coalescing, boot Off reset, or green/yellow bypass rules.

## What Changes

- Document the production RGB LED policy (red / yellow / green decision matrix, refresh sources, manual-override boundary).
- Document HAL/App blink idempotency and forced Off reset at policy start and LED Settings entry.
- Capture Laser Enable session + CNC wire-value (UI `ProcessType.wireValue` = 5) as the green ready inputs (not Modbus `control.laser_enable` / `process_type` alone).
- **Implementation already landed** in `app/lws_hmi` + `cyber_hal` GPIO; this change is primarily spec sync / archive-ready documentation (verify tasks, not greenfield coding).

## Capabilities

### New Capabilities
- `rgb-gpio-indicator-lights`: Operator-facing RGB chassis LED policy (parity with lws-ui `RgbLedDecision` / `GpioLedHandler`), including boot reset and LED Settings manual override.

### Modified Capabilities
- `linux-gpio-rgb-led`: Require same-mode blink not to restart the flash phase; support forced Off rewrite for boot / settings reset.
- `settings-ui`: LED Settings page SHALL force all colors Off on enter while suppressing production policy.

## Impact

- Specs: new `openspec/specs/rgb-gpio-indicator-lights/` after archive; deltas for `linux-gpio-rgb-led` and `settings-ui`.
- Code (already present): `RgbLedPolicyDriver`, `RgbLedDecision`, `LaserEnableLedHolder`, `GpioLedController.resetAllOff`, `cyber_hal` `GpioLine.setMode(force:)`, warn-alarm start wiring, Quick/Engineer holder updates, LED Settings page.
- Does not change GPIO pin labels (`GPIO_5/4/7`) or Modbus attribute map.
