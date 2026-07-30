## 1. App force-import API

- [x] 1.1 Add a `force` (or equivalent) flag to `ProcessLibraryImporter.importPackageFromDirectory` that bypasses same-version / older-version skip gates while keeping hash, schema, row-count, and model-match validation
- [x] 1.2 Cover forced same-version re-import and no-compatible-model rejection in `process_library_package_import_test.dart` (or adjacent test)

## 2. App command watcher

- [x] 2.1 Add `UpgradeProcessLibraryCommandWatcher` (mirror `SyncFirmwareCommandWatcher`) watching `/run/hmi/upgrade-process-library.cmd` for `upgrade <packageDir>` and `/run/hmi/reset-process-library.cmd` for `reset`
- [x] 2.2 On `upgrade`, call forced `importPackageFromDirectory`, reload `ProcessLibraryController` presets when available, and log outcomes; on `reset`, `clearAll` + force `importBundled` and log outcomes
- [x] 2.3 Wire watcher start/dispose in `app.dart` alongside the firmware watcher

## 3. Host upgrade-process-library

- [x] 3.1 Add `scripts/upgrade-process-library.sh`: USB-SSH session, read `/var/lib/hal/product.ini` `model`, map to `assets/process-library/<Model_With_Underscores>/`, fail if missing/blank model or no matching Excel
- [x] 3.2 Convert newest matching Excel via `convert-process-library.py` into a temp package (`manifest.json` + JSON); optional `PACKAGE_DIR=` override
- [x] 3.3 Upload package under `/run/hmi/process-library-upgrade/`, write `/run/hmi/upgrade-process-library.cmd`, print clear OK/ERROR messages
- [x] 3.4 Add Makefile target `upgrade-process-library` and `help` line

## 4. Host reset-process-library

- [x] 4.1 Add `scripts/reset-process-library.sh`: write `/run/hmi/reset-process-library.cmd` with `reset` (no HMI stop/start; no host sqlite3)
- [x] 4.2 Add Makefile target `reset-process-library` and `help` line

## 5. Docs

- [x] 5.1 Document both targets in README Make commands and AGENTS.md rebuild table (host-only; both need running HMI + watcher App once; neither restarts HMI)
