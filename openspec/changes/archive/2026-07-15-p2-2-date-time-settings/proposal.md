## Why

ynh960 boards often boot with a stale RTC (no battery / no NTP), which breaks TLS certificate windows and misdates logs. P2.1 already has an ad-hoc wall-clock sync inside the HTTP probe path; product Settings will need a proper clock page later. **P2.2** pulls a reusable **date/time platform API** forward now—with **manual set** and **network auto sync**—so Demo and future P5 Settings share one contract instead of scattering `date` / `hwclock` / HTTP Date logic.

## What Changes

- Add reusable **`DateTimeController`** (abstract + Linux backend): get/set wall clock, timezone, sync mode (**manual** vs **network**), and explicit **network sync** (reuse / centralize today’s `rdate` + HTTP `Date` + `wlan0-time-sync.sh` patterns; write RTC via `hwclock`).
- Persist sync mode + timezone under `/var/lib/hmi/` so Demo choices survive HMI restart (full boot-stack restore of other hardware prefs remains **P2.3**).
- Extend **P2 Demo** with a Date & Time section: live clock, date/time pickers (manual), timezone control, Manual / Network mode toggle, and Sync Now.
- Refactor **Linux HTTP client** to call `DateTimeController` (or shared helper) for stale-clock TLS prep instead of duplicating sync logic.
- Ensure rootfs has tools/`tzdata` needed for set + display (BusyBox `date`, `hwclock`, optional `rdate`/`wget` already used); **do not** enable `systemd-timesyncd` / chrony in this change (leave full NTP daemon / cloud policy to P5).
- Update plan §12 **P2.2** checklist when the change lands.

## Capabilities

### New Capabilities

- `linux-datetime`: Reusable date/time API — wall clock get/set, timezone, sync mode (manual / network), network sync + RTC write; Linux backend for flutter-pi HMI; Demo and P5 Settings share the same interface.

### Modified Capabilities

- `p2-device-demo-ui`: Home demo gains a Date & Time section wired to `DateTimeController` (display, manual edit, mode toggle, Sync Now).
- `linux-http-client`: Stale-clock sync before HTTPS SHALL go through the datetime platform path (no parallel private sync copy for the primary success path).

## Impact

- **App** (`app/hmi/`): new `lib/platform/datetime/` (or equivalent); Demo section; inject Linux impl like other P2.1 controllers; unit tests for mode / timezone parsing / clamp-or-validate; HTTP controller calls shared sync.
- **Rootfs / overlay**: optional tighten of `wlan0-time-sync.sh` as the shell backend for network sync; `tzdata` / `hwclock` availability; prefs under `/var/lib/hmi/` (e.g. `time-sync-mode`, `timezone`).
- **Docs**: `docs/flutter-pi-hmi-plan.md` §12 P2.2 progress; brief note in `app/hmi/README.md` platform table.
- **Non-goals**: Product Settings page / FrostUI; chrony / systemd-timesyncd as default daemons; cloud NTP policy UI; Android backend (P2.5 plugs later); P2.3 boot restore of Wi‑Fi/eth0 stacks.
