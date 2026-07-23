## Why

DateTime still persists sync mode and timezone as two standalone files (`time-sync-mode`, `timezone`), while output/input prefs already use mouse-style `key=value` conf files (`display.conf`, `sound.conf`, `keyboard.conf`, `mouse.conf`). Consolidating into `/var/lib/hmi/datetime.conf` keeps HAL persist cohesion consistent and simplifies restore/docs.

## What Changes

- **BREAKING (on-disk prefs):** Replace `/var/lib/hmi/time-sync-mode` and `/var/lib/hmi/timezone` with a single `/var/lib/hmi/datetime.conf` (`sync_mode=`, `timezone=`).
- Update `TimeSyncPrefs` / `LinuxDateTimeController` to read/write via shared `key_value_conf` upsert helpers (same pattern as `OutputPrefs`).
- Soft one-shot migration: if `datetime.conf` is missing but legacy files exist, import their values into the new conf (then prefer conf only).
- Update specs (`linux-datetime`, `os-path-layout`, `linux-settings-persist`), HAL/App README, and datetime unit tests.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `linux-datetime`: Persist path becomes `datetime.conf` with documented keys; defaults and API behavior unchanged.
- `os-path-layout`: `/var/lib/hmi/` inventory lists `datetime.conf` instead of bare `timezone` / `time-sync-mode`.
- `linux-settings-persist`: HMI state-dir listing reflects the merged datetime conf file.

## Impact

- **HAL:** `packages/cyber_hal/lib/src/time/*` (`TimeSyncPrefs`, `LinuxDateTimeController`); optional shared constants next to other conf roots.
- **App:** Docs/`README` path strings; Settings/Demo continue using `DateTimeController` (no UI API change). Tests that inject `syncModePath` / `timezonePath` need conf-path injection.
- **Rootfs / overlay:** No shell helpers currently write these prefs (grep clean); boot restore already goes through HAL `restorePersistedSettings` → datetime `ensureSaneForTls` / getTimezone apply path.
- **Devices in field:** Rely on one-shot migration from legacy files; no parallel dual-write after migration.
