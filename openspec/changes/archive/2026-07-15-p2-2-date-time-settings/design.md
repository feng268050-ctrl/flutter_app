## Context

P2.1 Demo proves Wi‑Fi / eth0 / HTTP, but board RTC often boots in the past (see archive notes and `linux_http_client_controller.dart` `_ensureWallClockForTls`). Overlay already ships `/usr/lib/lws-hmi/wlan0-time-sync.sh` (`rdate` → HTTP `Date` → `hwclock -w -u`). Plan **P2.2** asks for Demo date/time with a reusable **`DateTimeController`**; the user also requires **manual set** and **network auto sync** in this phase—without waiting for P5 chrony / product Settings.

Constraints:

- Product clock UI is P5; this change ships Demo + abstract API only.
- `BR2_PACKAGE_SYSTEMD_TIMESYNCD` / chrony stay **off** for P2.2 (plan: lighter sync now; daemon NTP later).
- Match existing platform module style (`lib/platform/*/`).

## Goals / Non-Goals

**Goals:**

- One Dart `DateTimeController` for wall clock, timezone, sync mode (**manual** | **network**), and network sync + RTC write.
- Demo section: show clock, edit date/time (manual), timezone, mode toggle, Sync Now.
- Network mode uses (and owns) the existing helper/`rdate`/HTTP Date ladder; HTTP HTTPS preflight calls the same API.
- Persist sync mode + timezone under `/var/lib/lws-hmi/` across HMI restarts.

**Non-Goals:**

- Product Settings / FrostUI / status-bar clock polish.
- Enabling chrony or systemd-timesyncd as always-on daemons.
- Cloud NTP policy / custom NTP server list UI (P5 may extend the same controller).
- Android backends (P2.5).
- P2.3 boot restore of Wi‑Fi / eth0 / other hardware stacks (timezone + sync-mode files may already be present for App read).

## Decisions

### D1 — Package layout: `lib/platform/datetime/`

```text
lib/platform/datetime/
  date_time_controller.dart          # abstract + enums + result types
  linux_date_time_controller.dart    # Process + prefs + helper
```

Demo and HTTP inject the abstract type; Linux impl constructed in `P2DemoPage` / `main` like Wi‑Fi / display.

**Why:** Same reuse path as audio/backlight/orientation; host unit tests with fakes.

### D2 — Sync modes: `manual` vs `network`

| Mode | Behavior |
|------|----------|
| `manual` | User (or API) sets wall clock / timezone; network sync MUST NOT run automatically on HTTPS preflight or periodic timers. Explicit Sync Now may still be offered in Demo for engineering, or gated—**Demo: Sync Now always callable; auto-only paths respect mode.** |
| `network` | Prefer network-sourced time. Stale clock (UTC year &lt; 2025, or configurable) or explicit Sync Now / App-triggered sync runs the network ladder. Manual set remains available as override and SHOULD leave mode as `manual` if the Demo Apply from pickers is used (or keep mode unless user toggles—**Choice: applying a manual date/time switches mode to `manual`**). |

Persist:

- `/var/lib/lws-hmi/time-sync-mode` — single line `manual` \| `network` (default **`network`** so first-boot TLS is healed when wlan/eth has connectivity).
- `/var/lib/lws-hmi/timezone` — IANA name when settable (e.g. `Asia/Shanghai`); if `timedatectl` / `/etc/localtime` unavailable, document fallback (fixed offset file or `TZ` file).

**Why:** Matches user “手动 + 联网自动”; default network fixes TLS without forcing Demo intervention.

### D3 — Network sync ladder (centralize existing logic)

Order (same as `wlan0-time-sync.sh` / HTTP controller):

1. If clock already “sane” (UTC year in 2025–2030 window, same as helper) → no-op success.
2. Run `/usr/lib/lws-hmi/wlan0-time-sync.sh` if present (preferred single shell entry).
3. Else Dart/Process: `rdate -s` known hosts → parse HTTP `Date` via `wget`/`date -s` → `hwclock -w -u`.

Refactor `LinuxHttpClientController._ensureWallClockForTls` to:

- Call `DateTimeController.ensureSaneForTls()` or `syncFromNetwork(onlyIfStale: true)` when mode is `network` or when clock is stale regardless of mode **for TLS rescue only**.

**TLS rescue exception:** Even in `manual` mode, if year &lt; 2025 and HTTPS is about to run, attempt one network sync (TLS survival). Log that it was an emergency sync and do **not** flip persisted mode. Demo can show a toast/status string.

**Why:** Keeps one implementation; HTTPS continues to work out of the box.

### D4 — Manual set API

```dart
enum TimeSyncMode { manual, network }

class DateTimeSet {
  final DateTime wallClock; // local or UTC — document: API uses local civil time + timezone id
  // or separate date + time of day; timezone string
}

abstract class DateTimeController {
  Future<DateTime> now(); // wall clock
  Future<String> getTimezone(); // IANA or documented token
  Future<void> setTimezone(String id);
  Future<TimeSyncMode> getSyncMode();
  Future<void> setSyncMode(TimeSyncMode mode);
  Future<void> setWallClock(DateTime local); // implies manual mode
  Future<TimeSyncResult> syncFromNetwork({bool onlyIfStale = false});
  Future<TimeSyncResult> ensureSaneForTls(); // D3 exception
  Future<void> dispose();
}
```

Linux: Prefer `timedatectl set-time` / `set-timezone` when available; else BusyBox `date -s` + `hwclock -w -u`. Timezone: symlink `/etc/localtime` from `/usr/share/zoneinfo/...` when `tzdata` present; else store preference and set `TZ` for HMI process only (document limitation).

After successful set: always `hwclock -w -u` when possible so reboot keeps time until next sync.

### D5 — Demo UI section

Add **Date & Time** on P2 demo (placement: near HTTP / Wi‑Fi, after network sections ready):

1. Live clock text (1 Hz tick from `DateTime.now()` / controller).
2. Timezone field or short picker (start with curated list: `UTC`, `Asia/Shanghai`, `America/Los_Angeles` — extend later).
3. Manual date + time editors (text fields or simple steppers sufficient for Demo; Soft keyboard / USB HID already available).
4. Exclusive or switch: **Manual** / **Network**.
5. Buttons: **Apply** (manual set), **Sync Now** (network ladder).
6. Status line: last sync result / error (non-fatal).

Do not block first frame; init post-frame.

### D6 — Rootfs / Buildroot

- Keep `wlan0-time-sync.sh`; optionally rename call site docs to “datetime helper” without breaking Wi‑Fi scripts that invoke it.
- Ensure `tzdata` (or busybox zoneinfo subset) if `Asia/Shanghai` must resolve; if image size pressures, ship minimal zone files under overlay.
- Do **not** enable timesyncd/chrony in this change.
- Verify `hwclock`, `date`, `rdate`/`wget` remain present (already used).

### D7 — Plan / docs touch

Mark P2.2 checklist items progressing in `docs/flutter-pi-hmi-plan.md` when implement completes; note in `app/hmi/README.md` platform table.

## Risks / Trade-offs

- **[Risk] BusyBox `date` format quirks** → Mitigation: reuse proven `-D '%a, %d %b %Y %H:%M:%S GMT'` path from helper; unit-test parsers on host where possible.
- **[Risk] No writable RTC / hwclock fails** → Mitigation: still set system time; report RTC write failure in `TimeSyncResult` without crashing; reboot may lose time until next network sync.
- **[Risk] Network sync without connectivity** → Mitigation: structured failure; Demo status; HTTPS emergency path already best-effort.
- **[Risk] Timezone without full tzdata** → Mitigation: curated zone list + document fallback; prefer shipping `Asia/Shanghai` + UTC at minimum for ynh960 China product target.
- **[Trade-off] No chrony** → Accept short-term drift; P5 can add daemon behind same `network` mode without API break.
- **[Trade-off] TLS rescue in manual mode** → Prefer correct HTTPS over pure mode purity; do not silently change persisted mode.

## Migration Plan

1. Land platform module + refactor HTTP to call it (behavior-compatible for HTTPS).
2. Add Demo section; board smoke: manual set → reboot → clock held via RTC; network Sync Now with wlan up; HTTPS probe with stale RTC.
3. No GPT / flash required if only App + existing helper; flash only if `tzdata` / overlay changes need rootfs rebuild.

Rollback: revert App modules; HTTP can temporarily restore private sync (avoid leaving broken import).

## Open Questions

1. Exact timezone UX: curated list vs free-text IANA — **default curated list** unless Product asks otherwise.
2. Whether Wi‑Fi stack-up should continue calling `wlan0-time-sync.sh` automatically when mode=`network` — **yes, keep**; controller still owns App-visible Sync Now.
3. Android P2.5 mapping (`AlarmManager` / Settings) — defer; interface only.
