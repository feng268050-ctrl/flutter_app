## Why

ynh960 boards report `System clock synchronized: no` because `systemd-timesyncd` was deliberately left out of the image (P2.2 used a one-shot `rdate` / HTTP `Date` ladder). Without a continuous NTP daemon the wall clock drifts after boot, which misdates logs, video metadata, and cloud uploads, and keeps TLS/DNSSEC fragile. It is time to turn timesync on as the product default.

## What Changes

- Enable **`BR2_PACKAGE_SYSTEMD_TIMESYNCD`** in the appliance systemd fragment; keep **chrony** off.
- Preset-enable **`systemd-timesyncd.service`** so NTP runs after network is available (does not gate `hmi.service`).
- Wire HAL **`DateTimeController`** sync mode to OS NTP: `network` → `timedatectl set-ntp true`; `manual` → `set-ntp false` (and keep manual wall-clock / RTC write behavior).
- Keep the existing one-shot sync ladder (`sync-time` / rdate / HTTP Date) as a **bootstrap / TLS emergency** path when the clock is still years-off before timesyncd has locked; continuous drift correction is timesyncd’s job.
- Update rootfs comments / `docs/network-stack.md` that still say “timesyncd stays off until product NTP.”
- Leave **DNSSEC/DoT off** for this change (first-boot chicken-and-egg remains; revisit after timesyncd is proven).

## Capabilities

### New Capabilities

- *(none)* — this extends existing systemd boot and datetime capabilities.

### Modified Capabilities

- `hmi-systemd-boot`: Minimal systemd image MUST enable **systemd-timesyncd** alongside networkd/resolved (instead of requiring it disabled).
- `linux-datetime`: Network sync mode MUST drive OS NTP via timesyncd; manual mode MUST disable NTP; one-shot ladder remains for stale/TLS bootstrap only.

## Impact

- Buildroot: `overlay/buildroot/chips/lws_hmi_systemd.config`, comment in `lws_hmi_network.config`.
- Rootfs: `etc/systemd/system-preset/99-appliance.preset`; optional timesyncd conf drop-in; `verify-env` / docs that assert timesyncd state; resolved.conf comment refresh.
- HAL: `LinuxDateTimeController` (`setSyncMode` / manual set ↔ `timedatectl set-ntp`); Settings Auto/Manual already maps to sync mode.
- Rebuild path: `apply-overlay` → rebuild **systemd** package (`br-make-packages.sh`) → `build-rootfs` → `upgrade` (Kconfig change, not overlay-only).
- Non-goals: chrony; cloud NTP server policy UI; enabling DNSSEC/DoT; Android backends.
