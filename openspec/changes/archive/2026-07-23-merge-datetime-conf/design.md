## Context

`LinuxDateTimeController` today persists two plain-text files under `/var/lib/hmi/`:

- `time-sync-mode` — single token `manual` | `network`
- `timezone` — IANA name (e.g. `Asia/Shanghai`)

Meanwhile HAL output/input prefs use mouse-style `key=value` conf files (`display.conf`, `sound.conf`, `keyboard.conf`, `mouse.conf`) via `key_value_conf` upsert helpers. Overlay shell does not write the datetime prefs; HAL owns mid-session write and cold-start apply.

## Goals / Non-Goals

**Goals:**

- Single preference file `/var/lib/hmi/datetime.conf` with keys `sync_mode` and `timezone`.
- Reuse `parseKeyValueConf` / `upsertKeyValueConfFile` (same as `OutputPrefs`).
- Soft one-shot import from legacy files when conf is absent.
- Specs + README + unit tests updated; public `DateTimeController` API unchanged.

**Non-Goals:**

- Changing sync ladder (`sync-time` / rdate / HTTP Date), RTC behavior, or curated timezone list.
- Moving datetime under `hal/output` or inventing a parallel prefs tree.
- Dual-write forever or keeping legacy paths as first-class APIs after migration.
- Shell `settings-restore` ownership of datetime (stays HAL `restorePersistedSettings` / App cold start).

## Decisions

### D1 — Path and keys

| File | Keys |
|------|------|
| `/var/lib/hmi/datetime.conf` | `sync_mode` (`manual` \| `network`), `timezone` (IANA string) |

**Rationale:** Matches `display.conf` / `sound.conf` naming (`<domain>.conf` + snake_case keys). `sync_mode` is clearer than bare filename token `time-sync-mode`.

**Alternatives considered:** Keep two files — rejected (inconsistent). Nest under `TimeSyncPrefs` only without a shared conf helper — rejected (duplication).

### D2 — Constants surface

Extend `TimeSyncPrefs` (keep existing helper methods) with:

- `datetimeConf = '/var/lib/hmi/datetime.conf'`
- `keySyncMode = 'sync_mode'`, `keyTimezone = 'timezone'`
- Deprecate / remove `syncModePath` and `timezonePath` as primary APIs (tests inject `preferencePath` like backlight).

`LinuxDateTimeController` takes a single `preferencePath` (default `TimeSyncPrefs.datetimeConf`) plus optional legacy path overrides only for migration tests.

**Alternatives:** New `DateTimePrefs` class mirroring `OutputPrefs` — acceptable if cleaner; either is fine so long as one source of truth.

### D3 — Read / write semantics

- **Read:** load conf map; missing `sync_mode` → default `network`; missing `timezone` → fall through to `timedatectl` then `UTC` (same as today).
- **Write:** `upsertKeyValueConfFile` so updating one key preserves the other.
- **Migrate (once):** if conf missing/empty of both keys, and legacy `time-sync-mode` and/or `timezone` files exist, copy values into conf. Do not delete legacy files in v1 (harmless leftovers; optional delete later). After conf has values, ignore legacy files.

### D4 — No dual-write

After this change, HAL MUST NOT write the legacy standalone files. Specs document conf as the sole persist path.

## Risks / Trade-offs

- **[Risk] Field devices lose prefs if migration skipped** → Mitigation: one-shot import on first get/set; unit-test migrate path.
- **[Risk] Concurrent writers** → Same as other conf files (single HMI process); upsert is read-modify-write, acceptable for this appliance.
- **[Trade-off] Leaving legacy files on disk** → Slight clutter vs safer rollback/debug; acceptable for v1.

## Migration Plan

1. Ship HAL that prefers `datetime.conf` and migrates on first touch.
2. Docs/specs list only `datetime.conf`.
3. Rollback: re-ship previous HAL that reads legacy files (conf ignored); or manually split conf keys back into two files.

## Open Questions

- None blocking; optional later cleanup of leftover legacy files can be a follow-up.
