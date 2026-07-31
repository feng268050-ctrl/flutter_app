## 1. Buildroot / image enablement

- [x] 1.1 Set `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y` in `overlay/buildroot/chips/lws_hmi_systemd.config`; remove the “not set” comment
- [x] 1.2 Update comment in `overlay/buildroot/chips/lws_hmi_network.config` (timesyncd is product NTP; chrony still off)
- [x] 1.3 Add `enable systemd-timesyncd.service` to `99-appliance.preset`
- [x] 1.4 Refresh `resolved.conf.d/10-appliance.conf` comment (timesyncd on; DNSSEC still off by choice)
- [x] 1.5 Add `verify-env` check that `systemd-timesyncd.service` is enabled

## 2. HAL sync mode ↔ OS NTP

- [x] 2.1 In `LinuxDateTimeController.setSyncMode`, call `timedatectl set-ntp true|false` for network/manual (fail soft if timedatectl/timesyncd absent)
- [x] 2.2 Ensure manual `setWallClock` path leaves NTP off (via setSyncMode(manual) or explicit set-ntp false)
- [x] 2.3 On HMI/HAL bring-up when persisted mode is `network`, apply `set-ntp true` so upgrades do not leave NTP stuck off
- [x] 2.4 Keep one-shot `syncFromNetwork` / `ensureSaneForTls` ladder for bootstrap; do not remove it
- [x] 2.5 Add/adjust cyber_hal unit tests for set-ntp argv on mode changes (process runner fake)

## 3. Docs

- [x] 3.1 Update `docs/network-stack.md` DNS row / NTP note: timesyncd is enabled; DNSSEC remains off until proven

## 4. Device verification

- [ ] 4.1 Rebuild systemd package (`bash scripts/br-make-packages.sh … systemd`), then `make apply-overlay`, `make build-rootfs`, `make upgrade`
- [ ] 4.2 On board: confirm `systemctl is-enabled systemd-timesyncd`, and after network that `timedatectl` shows NTP active and eventually `System clock synchronized: yes`
- [ ] 4.3 Confirm Settings Manual / Auto toggles NTP off/on without breaking TLS emergency sync when clock is stale
