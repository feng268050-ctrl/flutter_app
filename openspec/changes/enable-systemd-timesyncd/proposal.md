## Why

ynh960 product boards have an **external RTC** on **i2c5 @0x51** (PCF8563-compatible; EVB uses `nxp,pcf8563`). The RK809 PMIC RTC is unusable (internal RC ~15% slow when XIN/XOUT is missing) — Android leaves `rk808-rtc` probe disabled; Linux matches that. The rk3566 EVB2 base that ynh960 includes **omits** `rtc@51`, so Linux never bound the good chip until a ynh960 DT overlay adds it. Boot DT cannot live in `oem/` (U-Boot loads FIT before `/oem`). Optional Settings Automatic NTP remains available when online (CN NTP servers).

## What Changes

- Add `ynh960-rtc.dtsi` (`&i2c5` → `rtc@51` / `nxp,pcf8563`) and wire it via `apply-overlay.sh` / `patch-ynh960-dts.sh`.
- In `ynh960-rtc.config`: **unset `CONFIG_RTC_DRV_RK808`** (PMIC RTC must not register), enable `CONFIG_RTC_DRV_PCF8563`, HCTOSYS/SYSTOHC → `rtc0` (the external chip as the only RTC).
- Keep `0008-rk808-rtc-reenable-probe.patch` **removed** (do not re-enable PMIC RTC via source patch).
- Restore `rtc-systohc.timer` (`hwclock -w -f /dev/rtc0`); remove fake-hwclock units/script.
- Keep timesyncd **disabled** by default; CN NTP drop-in for opt-in Automatic.
- Default HAL sync mode **manual**; persist via `hwclock` only.

## Capabilities

### New Capabilities

- *(none)*

### Modified Capabilities

- `hmi-systemd-boot`: rtc-systohc units; timesyncd opt-in disabled at boot.
- `linux-datetime`: Offline persist via external RTC, not PMIC / fake-hwclock; network NTP opt-in only.

## Impact

- Kernel DT + fragment → `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade`.
- Overlay rtc-systohc + preset; HAL `hwclock` persist (no fake-hwclock).
- **Not** `OEM_ONLY=1` — DT is FIT kernel, not oem partition.
