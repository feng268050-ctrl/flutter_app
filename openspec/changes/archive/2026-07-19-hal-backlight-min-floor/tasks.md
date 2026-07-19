## 1. HAL remap helpers

- [x] 1.1 Add `kBacklightHwFloorPercent` and `backlightPercentToDevice` / `backlightDeviceToPercent` (logical 0–100 ↔ `[hwFloor, max]`); keep shared `clampPercent` for API
- [x] 1.2 Export floor/remap symbols from the backlight / output API surface as needed for tests (Demo does not clamp away 0)

## 2. Linux + stub backends

- [x] 2.1 `LinuxSysfsBacklight` set: clamp logical 0–100, write remap for sysfs, persist logical percent (including 0); get: reverse-map
- [x] 2.2 `StubBacklight`: logical 0–100 via `clampPercent` (no hardware floor required)
- [x] 2.3 Unit tests: set 0 → sysfs ≥ 1 + pref `0`; get at floor → 0; set 120 → 100; volume still allows 0

## 3. Demo UI

- [x] 3.1 Brightness `_PercentSlider` `min` = 0 (volume unchanged)
- [x] 3.2 Queued brightness apply passes logical 0–100 through to HAL (HAL remaps)

## 4. Specs sync and verify

- [x] 4.1 Confirm delta specs match logical-0 / hardware-floor behavior
- [x] 4.2 `flutter analyze` / relevant tests under `packages/cyber_hal` and `app/hmi`
- [x] 4.3 On device after `build-app` / `push-app`: drag brightness to 0 — UI shows 0, panel stays visible, pref file may be `0`, sysfs brightness ≠ 0
