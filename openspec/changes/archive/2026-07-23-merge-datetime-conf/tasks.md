## 1. HAL prefs API

- [x] 1.1 Update `TimeSyncPrefs` with `datetimeConf`, `keySyncMode`, `keyTimezone`; remove primary use of standalone `syncModePath` / `timezonePath`
- [x] 1.2 Refactor `LinuxDateTimeController` to single `preferencePath` + `key_value_conf` upsert/read; preserve sync/timezone apply behavior
- [x] 1.3 Add one-shot legacy import from `time-sync-mode` / `timezone` when conf lacks keys

## 2. Tests

- [x] 2.1 Update `app/hmi/test/platform_datetime_test.dart` (and any HAL datetime tests) for conf-path injection
- [x] 2.2 Add coverage: upsert preserves sibling key; legacy migrate once; default `sync_mode` when absent

## 3. Docs and call sites

- [x] 3.1 Update `packages/cyber_hal/README.md` and `app/hmi/README.md` persist path strings to `datetime.conf`
- [x] 3.2 Grep/fix remaining `time-sync-mode` / `/var/lib/hmi/timezone` references in App/Demo/docs (keep archive OpenSpec history as-is)

## 4. Verification

- [x] 4.1 Run datetime-related Flutter tests under `app/hmi/` (and `packages/cyber_hal/` if present)
- [x] 4.2 Spot-check Settings / Demo Date & Time still get/set mode and timezone after conf write
