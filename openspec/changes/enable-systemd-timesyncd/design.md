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

- Wall clock works **offline** from the **external PCF8563** on i2c5 @0x51 + manual Settings (product default).
- Leave RK809 PMIC RTC unregistered (`CONFIG_RTC_DRV_RK808` unset; RC-slow).
- Ship timesyncd only as **opt-in** Automatic when the user networks the device.
- Periodically persist system → RTC without requiring NTP (`rtc-systohc.timer`).
- CN-reachable NTP servers when Automatic is used.

**Non-Goals:**

- Fixing motherboard XIN/XOUT crystal for RK809 (not field-modifiable; unused for wall clock).
- Putting boot RTC DT nodes in `oem/` (FIT loads before `/oem`).
- Requiring network/NTP for normal timekeeping.
- chrony or cloud NTP policy UI.
- Enabling DNSSEC/DoT.
- Making HMI wait for NTP at boot.
- Claiming crystal-perfect absolute time offline (ppm drift remains a hardware limit).

## Decisions

### D1: systemd-timesyncd, not chrony

- **Choice:** `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y`; chrony remains unset.
- **Why:** Already on systemd stack (networkd/resolved); smallest dependency; `timedatectl` / `timedate1` NTP properties work without extra packages.
- **Alternatives:** chrony (heavier, better for multi-source / offline — not needed yet); keep one-shot only (status quo — clock drifts).

### D2: timesyncd installed, disabled at boot; external RTC + rtc-systohc

- **Choice:** Package timesyncd but `disable` at preset. Enable `rtc-systohc.timer` for offline `hwclock -w`. Bind external `nxp,pcf8563` @ i2c5 0x51 via `ynh960-rtc.dtsi`. **Unset `CONFIG_RTC_DRV_RK808`** so the slow PMIC RTC never registers (MFD regulators stay). Keep any `0008` reenable patch removed.
- **Why:** Measured: PMIC RTC ~15% slow; external chip ACKs and tracks arch_timer 1:1. Relying only on vendor `if (1) return` in `rtc-rk808.c` failed on flashed images where that gate was absent/reverted — Kconfig unset is deterministic. rk3566 EVB2 base omitted `rtc@51`; ynh960 overlay must add it. Fake-hwclock is unnecessary once the real RTC is `rtc0`.
- **Note:** `hmi.service` stays local-fs only. DT change is kernel/FIT, not OEM.

### D3: HAL sync mode drives `timedatectl set-ntp`

- **Choice:** On `setSyncMode(network)` and at controller init when mode is `network`, call `timedatectl set-ntp true`. On `setSyncMode(manual)` and successful `setWallClock`, call `timedatectl set-ntp false` (manual set already switches mode to manual).
- **Why:** Product Auto/Manual must match `NTP: yes/no` in `timedatectl`; otherwise timesyncd would overwrite operator-set time.
- **Alternatives:** Leave NTP always on and only use prefs for UI — breaks Manual; App-only sync without OS NTP — does not stop drift.

### D4: Keep one-shot ladder as bootstrap, not continuous sync

- **Choice:** `syncFromNetwork` / `ensureSaneForTls` keep the existing helper/rdate/HTTP ladder for immediate correction when year < 2025 (or explicit Sync Now). Continuous correction is timesyncd.
- **Why:** timesyncd can take minutes / need DNS; TLS probes need a fast path when RTC is years off. Avoid fighting timesyncd on every Settings tick when already sane (`onlyIfStale` no-op stays).
- **Optional later:** After NTP is enabled, Sync Now MAY also poke timesyncd / wait briefly — not required for v1 if ladder still works.

### D5: CN-reachable NTP servers (not Google FallbackNTP)

- **Choice:** Overlay drop-in `etc/systemd/timesyncd.conf.d/10-appliance.conf` with `NTP=ntp.aliyun.com ntp.tencent.com ntp.ntsc.ac.cn` and `FallbackNTP=cn.pool.ntp.org time.cloudflare.com`.
- **Why:** Buildroot/systemd compile-time FallbackNTP is `time*.google.com`. On ynh960 CN LAN those UDP/123 queries time out (`Packet count: 0`, `System clock synchronized: no`) while HTTP works — clock then drifts. Lab: Aliyun NTP locks within seconds (`synchronized: yes`, ~1 min correction).
- **Alternatives:** Keep Google defaults (fails in CN); chrony with same servers (heavier).

### D6: DNSSEC stays off

- **Choice:** Leave `DNSSEC=no` / `DNSOverTLS=no` in `10-appliance.conf`; only refresh the comment that timesyncd is now present.
- **Why:** First boot with wrong RTC still breaks DNSSEC before NTP lock; separate change after soak.

### D7: Package rebuild required

- **Choice:** Document `bash scripts/br-make-packages.sh systemd systemd` (or project-standard systemd rebuild) after flipping the Kconfig bit — `build-rootfs` alone will not rebuild systemd.
- **Why:** Same gotcha as other BR2_PACKAGE_SYSTEMD_* flips. NTP server drop-in is overlay-only (no systemd package rebuild).

## Risks / Trade-offs

- **[Risk] Manual time overwritten by NTP** → Mitigation: `set-ntp false` on manual mode / manual set (D3).
- **[Risk] NTP unreachable / firewall blocks UDP 123** → Mitigation: clock may still drift; one-shot HTTP Date ladder remains for TLS; document verify steps.
- **[Risk] Large step vs slew on first lock** → Accept timesyncd default behavior; RTC write after lock is timesyncd’s job when NTP is on.
- **[Risk] Spec `hmi-systemd-boot` currently forbids timesyncd** → Update delta in this change before archive.
- **[Trade-off] No chrony** → Accept timesyncd accuracy for appliance; upgrade path later if multi-source needed.

## Migration Plan

1. `FORCE_PLATFORM_OVERLAY=1 make apply-overlay`
2. `make build-kernel` (DT + HCTOSYS fragment)
3. `make build-rootfs` / `make upgrade` (rtc-systohc + drop fake-hwclock)
4. On device: `rtc0` = `rtc-pcf8563`; rate ~1.0 vs arch_timer; `hwclock -r` survives reboot.
