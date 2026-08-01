## 1. Buildroot / image enablement

- [x] 1.1 Set `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y` in `overlay/buildroot/chips/lws_hmi_systemd.config`; remove the “not set” comment
- [x] 1.2 Update comment in `overlay/buildroot/chips/lws_hmi_network.config` (timesyncd is product NTP; chrony still off)
- [x] 1.3 Preset-**enable** `systemd-timesyncd.service` (Automatic NTP default on)
- [x] 1.4 Refresh `resolved.conf.d/10-appliance.conf` comment (timesyncd on; DNSSEC still off by choice)
- [x] 1.5 `verify-env`: timesyncd binary/unit present; enabled by preset is PASS
- [x] 1.6 Add `rtc-systohc.service` + `.timer` (periodic `hwclock -w`) and preset-enable the timer
- [x] 1.7 Add `timesyncd.conf.d/10-appliance.conf` with `pool.ntp.org` then Cloudflare → Google → Aliyun
- [x] 1.8 Add `ynh960-rtc.dtsi` (`nxp,pcf8563` @ i2c5 0x51) + unset `CONFIG_RTC_DRV_RK808` + HCTOSYS/`CONFIG_RTC_DRV_PCF8563` in `ynh960-rtc.config` so external RTC is sole `rtc0`
- [x] 1.9 Remove fake-hwclock units/script; restore rtc-systohc as the persist path (`hwclock -f /dev/rtc0`)

## 2. HAL sync mode ↔ OS NTP

- [x] 2.1 In `LinuxDateTimeController.setSyncMode`, call `timedatectl set-ntp true|false` for network/manual (fail soft if timedatectl/timesyncd absent)
- [x] 2.2 Ensure manual `setWallClock` path leaves NTP off (via setSyncMode(manual) or explicit set-ntp false)
- [x] 2.3 On HMI/HAL bring-up apply persisted sync mode (default **network** → NTP on)
- [x] 2.4 Keep one-shot `syncFromNetwork` / `ensureSaneForTls` ladder for bootstrap; do not remove it
- [x] 2.5 Add/adjust cyber_hal unit tests for set-ntp argv + default network
- [x] 2.6 Settings Date & Time initial mode = network
- [x] 2.7 Persist wall clock via `hwclock` only (no fake-hwclock)
- [x] 2.8 Link-up watcher: **product primary** (`PrimaryNetworkController` / RouteMetric) IPv4 rising edge → `syncFromNetwork` when Automatic; non-primary (camera eth) ignored
- [x] 2.9 Product API `setPrimaryRole` / `getPrimaryRole` → `/var/lib/network/primary.conf`; lws_hmi defaults Wi‑Fi when unset

## 3. Docs

- [x] 3.1 Update `docs/network-stack.md`: external RTC for offline; Automatic NTP default on; rtc-systohc; not OEM DT

## 4. Device verification

- [ ] 4.1 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`, `make build-kernel`, `make build-rootfs`, `make upgrade`
- [ ] 4.2 Live board: `rtc0` = pcf8563; rate ~1.0; NTP active by default + rtc-systohc
- [ ] 4.3 Confirm Settings Automatic (default) syncs when networked; Manual stays on RTC
- [x] 4.4 Product rule: do not require network for offline wall clock (external RTC)
