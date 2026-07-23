## Why

`GpioLedManager` exposes nine color-specific methods (`redLightAlways`, `yellowLightFlash`, …) with duplicated idempotency, synchronization, and flash-task wiring. DevActivity carries a large manual-test surface (GPIO/Light buttons, pause flags, `suspendForManualControl`) that is no longer needed in production and blurs the boundary between hardware driver and debug tooling. A single `LedIndicatorManager` with color/mode enums will simplify `GpioLedHandler` and keep operator LED semantics unchanged.

## What Changes

- **Rename and replace** `GpioLedManager` → `LedIndicatorManager` with a unified API: `setIndicator(LedColor, IndicatorMode)` where `IndicatorMode` is `OFF`, `BLINK`, or `STEADY_ON`.
- **Introduce** `LedColor` enum (`RED`, `YELLOW`, `GREEN`) mapping to `GpioLedConfig` GPIO pins.
- **Consolidate** flash scheduling into one internal path shared by red and yellow; keep existing 1 s on / 1 s off (2 s period) timing.
- **Remove DevActivity LED debug UI and code**: RGB manual buttons, raw GPIO/Light PWM panels, `led_status_text`, `enterManualLedTestMode` / `leaveManualLedTestMode`, and `GpioLedHandler.setAutoRefreshPaused` / `isAutoRefreshPaused`.
- **Remove Dev-only manager APIs**: `suspendForManualControl()`, `closeAllLights()`, per-color `isRedLight*` query methods (unless still needed internally).
- **Update** `GpioLedHandler` to call the unified API; retain `RgbLedDecision` business rules unchanged.
- **BREAKING**: Any direct `GpioLedManager` imports are removed; class and package path change.

## Capabilities

### New Capabilities

_(none — refactor within existing indicator capability)_

### Modified Capabilities

- `rgb-gpio-indicator-lights`: Hardware driver class rename (`LedIndicatorManager`), unified color/mode API, removal of Dev/debug direct-access exception, flash timing constants live on the new manager.

## Impact

- `app/src/main/java/.../gpio/GpioLedManager.java` → `LedIndicatorManager.java`
- `GpioLedHandler`, `LaserApplication` (`initAllLedStatus` → equivalent bootstrap)
- `DevActivity` + `activity_dev.xml` (LED sections removed; non-LED dev tools unchanged)
- `LogTAGConstant`, unit tests referencing `GpioLedManager`
- OpenSpec main spec `openspec/specs/rgb-gpio-indicator-lights/spec.md` (driver naming + no Dev exception)
