## MODIFIED Requirements

### Requirement: Red and yellow flash timing

Red standby blink and yellow alarm blink SHALL share one timing profile in `LedIndicatorManager`:

- `FLASH_ON_MS = 1000`
- `FLASH_OFF_MS = 1000`
- Effective blink rate: **one full cycle every 2 s** (1 s on, 1 s off)

Red and yellow MUST use the same constants; green does not blink.

#### Scenario: Flash task interval matches on/off duration

- **WHEN** red or yellow enters blink mode via `LedIndicatorManager.setIndicator(color, IndicatorMode.BLINK)`
- **THEN** the scheduled flash task interval MUST equal `FLASH_ON_MS + FLASH_OFF_MS` (2000 ms)

### Requirement: RGB LED decisions are centralized

GPIO indicator decisions MUST be computed in `GpioLedHandler` (via `RgbLedDecision` or equivalent). Production work screens MUST NOT call `LedIndicatorManager` directly for red/yellow/green behavior.

`LedIndicatorManager` SHALL expose a unified hardware API: `setIndicator(LedColor, IndicatorMode)` where `LedColor` is `RED`, `YELLOW`, or `GREEN` and `IndicatorMode` is `OFF`, `BLINK`, or `STEADY_ON`.

#### Scenario: Poll cycle drives LEDs

- **WHEN** a normal Modbus poll cycle completes `finishPollCycle`
- **THEN** `GpioLedHandler` MUST update red, yellow, and green from cached device status and laser-enable state via `LedIndicatorManager.setIndicator`

#### Scenario: No YNHAPI on emulator

- **WHEN** YNHAPI is unavailable
- **THEN** LED refresh MUST no-op without crashing
