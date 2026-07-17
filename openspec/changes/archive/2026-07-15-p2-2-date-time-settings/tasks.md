## 1. Platform scaffolding

- [x] 1.1 Create `app/hmi/lib/platform/datetime/` with abstract `DateTimeController`, `TimeSyncMode`, and `TimeSyncResult` per design D1/D4
- [x] 1.2 Implement `LinuxDateTimeController`: prefs `/var/lib/hmi/time-sync-mode` + `timezone`; default mode `network`
- [x] 1.3 Implement manual `setWallClock` / `setTimezone` via `timedatectl` or BusyBox `date` + `hwclock -w -u`; applying wall clock sets mode to `manual`
- [x] 1.4 Implement `syncFromNetwork` / `ensureSaneForTls` using `wlan0-time-sync.sh` then `rdate` / HTTP Date ladder (design D3)
- [x] 1.5 Host unit tests: mode default/persist parsing, timezone token, stale-year window skip, manual set switches mode (fakes / file prefs under temp dir)

## 2. Integrate HTTP + rootfs helpers

- [x] 2.1 Refactor `LinuxHttpClientController` to call `DateTimeController.ensureSaneForTls` (inject optional controller; default Linux impl) instead of private sync as primary path
- [x] 2.2 Confirm overlay `wlan0-time-sync.sh` remains the shell entry; adjust only if helper contract must expose clearer exit codes for Dart
- [x] 2.3 Ensure `tzdata` (or minimal zoneinfo for `UTC` + `Asia/Shanghai`) and `hwclock`/`date`/`rdate`|`wget` available; document if overlay seed needed (`apply-overlay` / Buildroot fragment)

## 3. Demo UI

- [x] 3.1 Add `date_time_demo_section.dart` (or equivalent) with live clock, curated timezone list, Manual/Network mode, Apply, Sync Now, status line
- [x] 3.2 Wire section into `P2DemoPage` (inject `DateTimeController`; post-frame init; non-fatal errors)
- [x] 3.3 Widget/unit tests for demo section callbacks (fake controller) as needed for CI

## 4. Verify & docs

- [x] 4.1 `flutter analyze` / tests under `app/hmi/`
- [x] 4.2 Device smoke: manual set → verify `date` + RTC; Sync Now with wlan/eth; HTTPS probe with forced stale clock; mode persist across HMI restart
- [x] 4.3 Update `docs/flutter-pi-hmi-plan.md` §12 P2.2 checklist items covered by this change
- [x] 4.4 Update `app/hmi/README.md` platform table for datetime module
