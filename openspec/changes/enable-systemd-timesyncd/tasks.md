## 1. Buildroot / image enablement

- [x] 1.1 Set `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y` in `overlay/buildroot/chips/lws_hmi_systemd.config`; remove the “not set” comment
- [x] 1.2 Update comment in `overlay/buildroot/chips/lws_hmi_network.config` (timesyncd is product NTP; chrony still off)
- [x] 1.3 Preset-**disable** `systemd-timesyncd.service` (RTC-first; NTP opt-in via Settings Automatic)
- [x] 1.4 Refresh `resolved.conf.d/10-appliance.conf` comment (timesyncd on; DNSSEC still off by choice)
- [x] 1.5 `verify-env`: timesyncd binary/unit present; disabled by preset is PASS
- [x] 1.6 Add `rtc-systohc.service` + `.timer` (periodic `hwclock -w`) and preset-enable the timer
- [x] 1.7 Add `timesyncd.conf.d/10-appliance.conf` with CN NTP for opt-in Automatic
- [x] 1.8 Add `ynh960-rtc.dtsi` (`nxp,pcf8563` @ i2c5 0x51) + unset `CONFIG_RTC_DRV_RK808` + HCTOSYS/`CONFIG_RTC_DRV_PCF8563` in `ynh960-rtc.config` so external RTC is sole `rtc0`
- [x] 1.9 Remove fake-hwclock units/script; restore rtc-systohc as the persist path (`hwclock -f /dev/rtc0`)

## 2. HAL sync mode ↔ OS NTP

- [x] 2.1 In `LinuxDateTimeController.setSyncMode`, call `timedatectl set-ntp true|false` for network/manual (fail soft if timedatectl/timesyncd absent)
- [x] 2.2 Ensure manual `setWallClock` path leaves NTP off (via setSyncMode(manual) or explicit set-ntp false)
- [x] 2.3 On HMI/HAL bring-up apply persisted sync mode (default **manual** → NTP off)
- [x] 2.4 Keep one-shot `syncFromNetwork` / `ensureSaneForTls` ladder for bootstrap; do not remove it
- [x] 2.5 Add/adjust cyber_hal unit tests for set-ntp argv + default manual
- [x] 2.6 Settings Date & Time initial mode = manual
- [x] 2.7 Persist wall clock via `hwclock` only (no fake-hwclock)

## 3. Docs

- [x] 3.1 Update `docs/network-stack.md`: external RTC-first; NTP opt-in; rtc-systohc; not OEM DT

## 4. Device verification

- [ ] 4.1 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade`
- [ ] 4.2 Live board: `rtc0` = pcf8563; rate ~1.0; NTP inactive + `sync_mode=manual` + rtc-systohc
- [ ] 4.3 Confirm Settings Automatic still opt-in syncs when networked; Manual stays on RTC
- [x] 4.4 Product rule: do not require network for wall clock
