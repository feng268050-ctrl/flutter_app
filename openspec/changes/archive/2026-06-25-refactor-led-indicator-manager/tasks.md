## 1. Core types and manager

- [x] 1.1 Add `LedColor` enum (`RED`, `YELLOW`, `GREEN`) with `gpioPin()` mapping to `GpioLedConfig`
- [x] 1.2 Add `IndicatorMode` enum (`OFF`, `BLINK`, `STEADY_ON`)
- [x] 1.3 Implement `LedIndicatorManager` with `setIndicator`, `getIndicatorMode`, `isHardwareAvailable`, `syncHardwareToCachedModes`
- [x] 1.4 Unify flash scheduling: shared task body, per-color task IDs, `FLASH_ON_MS`/`FLASH_OFF_MS` = 1000
- [x] 1.5 Add `LogTAGConstant.LedIndicatorManager` and use in new manager

## 2. Migrate callers

- [x] 2.1 Refactor `GpioLedHandler`: remove `autoRefreshPaused` / `setAutoRefreshPaused` / `isAutoRefreshPaused`; map `RgbLedDecision` modes → `LedIndicatorManager.setIndicator`
- [x] 2.2 Update `LaserApplication` to call `LedIndicatorManager.syncHardwareToCachedModes()` instead of `GpioLedManager.initAllLedStatus()`
- [x] 2.3 Delete `GpioLedManager.java` and remove all remaining imports/references

## 3. Remove DevActivity LED tooling

- [x] 3.1 Remove LED/GPIO/Light sections from `activity_dev.xml` (keep video/record/camera dev tools)
- [x] 3.2 Remove LED-related methods, lifecycle hooks, and imports from `DevActivity.java`

## 4. Tests and verification

- [x] 4.1 Add or migrate unit tests for `LedIndicatorManager` idempotency and mode transitions (mock or skip GPIO when API unavailable)
- [x] 4.2 Confirm existing `RgbLedDecision` / `GpioLedHandler` tests still pass
- [x] 4.3 Run `./gradlew :app:testDebugUnitTest` and `make sync` on emulator

## 5. Spec archive prep

- [x] 5.1 Grep repo for `GpioLedManager` — expect zero production references after migration
