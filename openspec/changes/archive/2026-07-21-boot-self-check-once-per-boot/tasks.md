## 1. Boot marker + gate

- [x] 1.1 Add injectable boot marker path (default `/run/hmi/boot-self-check-done`) with `exists` / `mark` helpers; mkdir parent best-effort; soft-fail on I/O errors
- [x] 1.2 Extend `BootSelfCheckGate` so `markCompletedInProcess` / completion paths also mark this boot; expose `hasCompletedThisBoot` (or fold into a single “should skip” check)
- [x] 1.3 Wire `OsPaths` (or local constant) for `/run/hmi` if useful; keep test injection without touching real `/run`

## 2. Coordinator

- [x] 2.1 In `BootSelfCheckCoordinator.startWhenHomeEntered`, skip when boot marker exists (before starting dialog), same as in-process complete
- [x] 2.2 On preference-disabled skip path, mark boot consumed (not only in-process)
- [x] 2.3 On successful finish / finally completion paths, ensure boot marker is written

## 3. Tests

- [x] 3.1 Unit tests: marker write → second “process” (reset in-process only) skips; missing marker allows start
- [x] 3.2 Unit tests: preference disabled marks boot consumed; subsequent start with preference forced enabled still skips while marker present
- [x] 3.3 Update any coordinator/widget tests that assumed only in-process gating
- [x] 3.4 Run `flutter test` / `flutter analyze` under `app/hmi/` for touched files

## 4. Docs / verify

- [x] 4.1 Confirm no overlay changes required; smoke on device: first boot shows dialog, `systemctl restart hmi` does not
