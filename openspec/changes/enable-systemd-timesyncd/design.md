## Context

P2.2 deliberately left `BR2_PACKAGE_SYSTEMD_TIMESYNCD` unset and used a one-shot network ladder (`/usr/bin/sync-time` → rdate / HTTP `Date` → `hwclock`) via `LinuxDateTimeController`. That fixes “RTC stuck in 2024” for TLS, but does **not** keep the clock synchronized: operators see `timedatectl` → `System clock synchronized: no` and the wall clock drifts.

The image already has systemd as PID 1 plus **networkd** + **resolved**. Enabling timesyncd is the natural companion and matches what Settings “Automatic” sync mode should mean at OS level (`timedatectl set-ntp`).

Constraints:

- Do not gate `hmi.service` on `network-online` or timesync lock (boot KPI / first frame).
- Keep Plan A minimal systemd: enable timesyncd only; still no logind / polkit / chrony.
- Existing HAL prefs (`/var/lib/hal/datetime.conf` `sync_mode=manual|network`) and Settings Auto/Manual UI stay the product contract.

## Goals / Non-Goals

**Goals:**

- Ship and enable `systemd-timesyncd` so NTP corrects drift whenever the network can reach default NTP servers.
- Map HAL sync mode ↔ OS NTP (`set-ntp true/false`).
- Preserve one-shot ladder for stale-clock / TLS emergency before timesyncd has locked.
- Update specs/docs that still require timesyncd to stay off.

**Non-Goals:**

- chrony or custom NTP pool UI / cloud NTP policy.
- Enabling DNSSEC or DNSOverTLS (still unsafe on first boot before sync).
- Changing Settings UI layout beyond existing Auto/Manual behavior.
- Making HMI wait for NTP at boot.

## Decisions

### D1: systemd-timesyncd, not chrony

- **Choice:** `BR2_PACKAGE_SYSTEMD_TIMESYNCD=y`; chrony remains unset.
- **Why:** Already on systemd stack (networkd/resolved); smallest dependency; `timedatectl` / `timedate1` NTP properties work without extra packages.
- **Alternatives:** chrony (heavier, better for multi-source / offline — not needed yet); keep one-shot only (status quo — clock drifts).

### D2: Preset-enable at image build

- **Choice:** `enable systemd-timesyncd.service` in `99-appliance.preset` (same pattern as networkd/resolved).
- **Why:** Survive `preset-all` during rootfs; no App-owned start path required.
- **Note:** timesyncd starts with network; if no route yet it waits — fine. `hmi.service` stays local-fs only.

### D3: HAL sync mode drives `timedatectl set-ntp`

- **Choice:** On `setSyncMode(network)` and at controller init when mode is `network`, call `timedatectl set-ntp true`. On `setSyncMode(manual)` and successful `setWallClock`, call `timedatectl set-ntp false` (manual set already switches mode to manual).
- **Why:** Product Auto/Manual must match `NTP: yes/no` in `timedatectl`; otherwise timesyncd would overwrite operator-set time.
- **Alternatives:** Leave NTP always on and only use prefs for UI — breaks Manual; App-only sync without OS NTP — does not stop drift.

### D4: Keep one-shot ladder as bootstrap, not continuous sync

- **Choice:** `syncFromNetwork` / `ensureSaneForTls` keep the existing helper/rdate/HTTP ladder for immediate correction when year < 2025 (or explicit Sync Now). Continuous correction is timesyncd.
- **Why:** timesyncd can take minutes / need DNS; TLS probes need a fast path when RTC is years off. Avoid fighting timesyncd on every Settings tick when already sane (`onlyIfStale` no-op stays).
- **Optional later:** After NTP is enabled, Sync Now MAY also poke timesyncd / wait briefly — not required for v1 if ladder still works.

### D5: Default NTP servers / no custom conf unless needed

- **Choice:** Use timesyncd defaults (vendor/fallback NTP); add an overlay drop-in only if Buildroot/Rockchip defaults are empty or wrong for CN networks.
- **Why:** Avoid inventing a server list without field data; revisit if lock fails on ynh960 LAN.
- **Verify on device:** `timedatectl timesync-status` / `System clock synchronized: yes` after eth0/wlan has DNS+route.

### D6: DNSSEC stays off

- **Choice:** Leave `DNSSEC=no` / `DNSOverTLS=no` in `10-appliance.conf`; only refresh the comment that timesyncd is now present.
- **Why:** First boot with wrong RTC still breaks DNSSEC before NTP lock; separate change after soak.

### D7: Package rebuild required

- **Choice:** Document `bash scripts/br-make-packages.sh systemd systemd` (or project-standard systemd rebuild) after flipping the Kconfig bit — `build-rootfs` alone will not rebuild systemd.
- **Why:** Same gotcha as other BR2_PACKAGE_SYSTEMD_* flips.

## Risks / Trade-offs

- **[Risk] Manual time overwritten by NTP** → Mitigation: `set-ntp false` on manual mode / manual set (D3).
- **[Risk] NTP unreachable / firewall blocks UDP 123** → Mitigation: clock may still drift; one-shot HTTP Date ladder remains for TLS; document verify steps.
- **[Risk] Large step vs slew on first lock** → Accept timesyncd default behavior; RTC write after lock is timesyncd’s job when NTP is on.
- **[Risk] Spec `hmi-systemd-boot` currently forbids timesyncd** → Update delta in this change before archive.
- **[Trade-off] No chrony** → Accept timesyncd accuracy for appliance; upgrade path later if multi-source needed.

## Migration Plan

1. Flip Buildroot fragment + preset + HAL NTP wiring + docs.
2. Rebuild systemd package, rootfs, upgrade board.
3. Verify: `systemctl is-enabled systemd-timesyncd`; after network, `timedatectl` shows NTP yes and eventually synchronized yes; Settings Manual disables NTP.
4. Rollback: unset TIMESYNCD, remove preset enable, rebuild systemd/rootfs (HAL `set-ntp` calls become no-ops / fail soft if binary absent).

## Open Questions

- None blocking: use stock NTP servers first; add CN-friendly pool drop-in only if ynh960 fails to lock in lab.
