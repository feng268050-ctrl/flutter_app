## Why

The HAL backlight API maps logical **0%** straight to sysfs `brightness=0`, which extinguishes the panel. On a touch HMI with no hardware brightness key, the operator cannot recover the UI. Absolute hardware zero is not a useful product outcome; the API and UI MUST still allow a logical **0** (dimmest), but that value MUST map onto a non-zero hardware floor.

## What Changes

- Keep the portable backlight API and Demo slider as **0–100** (logical percent, including 0).
- Remap logical 0–100 onto a hardware range `[hwFloor, max_brightness]` so sysfs never receives absolute 0 from HAL set/restore.
- Persist the **logical** percent (including `0`) under `/var/lib/hmi/backlight-brightness`; apply remaps on write.
- Document the logical vs hardware distinction in `linux-backlight` (and align persist wording).

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `linux-backlight`: Logical percent remains 0–100; HAL apply MUST NOT write sysfs absolute 0; get MUST reverse-map so the dimmest usable hardware level reports as logical 0.
- `shell-hw-persist`: Backlight preference remains 0–100 logical; applying `0` MUST NOT extinguish the panel.

## Impact

- **HAL:** `packages/cyber_hal` — percent↔device remap helpers; `LinuxSysfsBacklight` set/get; unit tests. Stub stays logical 0–100 (no hardware).
- **App:** Demo brightness slider stays `min: 0`; no UI floor.
- **Persist:** `/var/lib/hmi/backlight-brightness` MAY contain `0` (logical dimmest).
- **Not in scope:** Media volume; intentional panel power-off / DPMS APIs.
