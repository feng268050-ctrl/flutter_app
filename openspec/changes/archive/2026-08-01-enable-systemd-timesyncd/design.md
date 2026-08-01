## Context

P2.2 deliberately left `BR2_PACKAGE_SYSTEMD_TIMESYNCD` unset and used a one-shot network ladder (`/usr/bin/sync-time` → rdate / HTTP `Date` → `hwclock`) via `LinuxDateTimeController`. That fixes “RTC stuck in 2024” for TLS, but does **not** keep the clock synchronized: operators see `timedatectl` → `System clock synchronized: no` and the wall clock drifts.

The image already has systemd as PID 1 plus **networkd** + **resolved**. Enabling timesyncd is the natural companion and matches what Settings “Automatic” sync mode should mean at OS level (`timedatectl set-ntp`).

Constraints:

- Do not gate `hmi.service` on `network-online` or timesync lock (boot KPI / first frame).
- Keep Plan A minimal systemd: enable timesyncd only; still no logind / polkit / chrony.
- Existing HAL prefs (`/var/lib/hal/datetime.conf` `sync_mode=manual|network`) and Settings Auto/Manual UI stay the product contract.
- Boot device tree is in the FIT / `overlay/kernel` — **not** oem (see `docs/linux-sdk-vendor-import.md`).

## Goals / Non-Goals

**Goals:**

- Wall clock works **offline** from the **external PCF8563** on i2c5 @0x51 (RTC accuracy without network).
- Leave RK809 PMIC RTC unregistered (`CONFIG_RTC_DRV_RK808` unset; RC-slow).
- Ship timesyncd **enabled by default** (Settings Automatic on; HAL `sync_mode` defaults to `network`).
- Periodically persist system → RTC without requiring NTP (`rtc-systohc.timer` → `hwclock -w -u -f /dev/rtc0`) so offline reboot stays sane.
- NTP: overlay seed `pool.ntp.org` → Cloudflare → Google → Aliyun; runtime curated `20-hmi-ntp.conf` after HMI bring-up.

**Non-Goals:**

- Fixing motherboard XIN/XOUT crystal for RK809 (not field-modifiable; unused for wall clock).
- Putting boot RTC DT nodes in `oem/` (FIT loads before `/oem`).
- Requiring network/NTP for normal **offline** timekeeping (RTC covers that).
- chrony or cloud NTP policy UI.
- Enabling DNSSEC/DoT.
- Making HMI wait for NTP at boot.
- Claiming crystal-perfect absolute time offline (ppm drift remains a hardware limit).

## Decisions

### D1: systemd-timesyncd, not chrony

- **Choice:** `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y`; chrony remains unset.
- **Why:** Already on systemd stack (networkd/resolved); smallest dependency; `timedatectl` / `timedate1` NTP properties work without extra packages.
- **Alternatives:** chrony (heavier, better for multi-source / offline — not needed yet); keep one-shot only (status quo — clock drifts).

### D2: timesyncd enabled at boot; external RTC + rtc-systohc

- **Choice:** Package timesyncd and **`enable`** at preset (Automatic default on). Enable `rtc-systohc.timer` for offline `hwclock -w`. Bind external `nxp,pcf8563` @ i2c5 0x51 via `ynh960-rtc.dtsi`. **Unset `CONFIG_RTC_DRV_RK808`** so the slow PMIC RTC never registers (MFD regulators stay). Keep any `0008` reenable patch removed.
- **Why:** External RTC must remain correct offline; when networked, continuous NTP is the product default (not opt-in). Measured: PMIC RTC ~15% slow; external chip ACKs and tracks arch_timer 1:1. Fake-hwclock is unnecessary once the real RTC is `rtc0`.
- **Note:** `hmi.service` stays local-fs only. DT change is kernel/FIT, not OEM. Manual mode still calls `timedatectl set-ntp false`.

### D3: HAL sync mode drives `timedatectl set-ntp`

- **Choice:** Default sync mode when prefs are missing is **`network`**. On `setSyncMode(network)` and at bring-up when mode is `network`, call `timedatectl set-ntp true`. On `setSyncMode(manual)` and successful `setWallClock`, call `timedatectl set-ntp false`.
- **Why:** Automatic must match `NTP: yes` in `timedatectl` by default; Manual must not be overwritten by timesyncd.
- **Alternatives:** Leave NTP always on and only use prefs for UI — breaks Manual; App-only sync without OS NTP — does not stop drift.

### D4: Keep one-shot ladder as bootstrap + primary link-up nudge

- **Choice:** `syncFromNetwork` / `ensureSaneForTls` keep the existing helper/rdate/HTTP ladder for immediate correction when year < 2025 (or explicit Sync Now). Continuous correction is timesyncd via `setSyncMode` / `applyPersistedSyncMode` → `timedatectl set-ntp` (ladder itself does **not** toggle NTP). Additionally, `NetworkTimeSyncWatcher` listens only to the **product primary** from `PrimaryNetworkController` (`/var/lib/network/primary.conf`, else lowest board `route_metrics`) and calls `syncFromNetwork` on that iface’s IPv4 rising edge when Automatic is on. Non-primary ifaces (e.g. camera Ethernet) are ignored.
- **Why:** timesyncd can take minutes / need DNS; TLS probes need a fast path when RTC is years off; operators expect “uplink just connected → clock corrects soon.” Product `setPrimaryRole` owns which iface is internet; board metrics are fallbacks only.
- **Optional later:** After NTP is enabled, Sync Now MAY also poke timesyncd / wait briefly — not required for v1 if ladder still works.

### D5: NTP server preference (seed + runtime curated drop-in)

- **Choice:** Overlay seed `etc/systemd/timesyncd.conf.d/10-appliance.conf` with `NTP=pool.ntp.org` and `FallbackNTP=time.cloudflare.com time.google.com ntp.aliyun.com`. After HMI/HAL bring-up, `applyPersistedNtpServer` writes `/etc/systemd/timesyncd.conf.d/20-hmi-ntp.conf` with `NTP=<persisted primary>` (default `pool.ntp.org`) and `FallbackNTP=` the remaining curated presets (also Windows, Apple, Tencent, `cn.pool.ntp.org`), then restarts timesyncd (soft-fail).
- **Why:** Seed covers first boot before App runs; runtime drop-in matches Settings picker (`NtpServerCatalog`) without baking every hostname into the image overlay.
- **Alternatives:** CN-only Aliyun-first (previous opt-in lab config); chrony with same servers (heavier).

### D6: DNSSEC stays off

- **Choice:** Leave `DNSSEC=no` / `DNSOverTLS=no` in resolved `10-appliance.conf`; only refresh the comment that timesyncd is now present.
- **Why:** First boot with wrong RTC still breaks DNSSEC before NTP lock; separate change after soak.

### D7: Package rebuild required

- **Choice:** Document `bash scripts/br-make-packages.sh systemd systemd` (or project-standard systemd rebuild) after flipping the Kconfig bit — `build-rootfs` alone will not rebuild systemd.
- **Why:** Same gotcha as other BR2_PACKAGE_SYSTEMD_* flips. NTP server drop-in is overlay-only (no systemd package rebuild).

## Risks / Trade-offs

- **[Risk] Manual time overwritten by NTP** → Mitigation: `set-ntp false` on manual mode / manual set (D3).
- **[Risk] NTP unreachable / firewall blocks UDP 123** → Mitigation: offline RTC + one-shot HTTP Date ladder for TLS; clock may drift until NTP works.
- **[Risk] Large step vs slew on first lock** → Accept timesyncd default behavior; RTC write after lock is timesyncd’s job when NTP is on.
- **[Risk] Spec `hmi-systemd-boot` previously forbade timesyncd** → Update delta in this change before archive.
- **[Trade-off] No chrony** → Accept timesyncd accuracy for appliance; upgrade path later if multi-source needed.

## Migration Plan

1. `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`
2. `make build-kernel` (DT + HCTOSYS fragment)
3. `make build-rootfs` / `make upgrade` (rtc-systohc + timesyncd preset + NTP drop-in)
4. On device: `rtc0` = `rtc-pcf8563`; rate ~1.0 vs arch_timer; `hwclock -r` survives reboot; with network, `timedatectl` shows NTP active / synchronized.
