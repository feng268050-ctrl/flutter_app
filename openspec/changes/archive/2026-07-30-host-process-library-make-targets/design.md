## Context

`make upgrade-control-board` uploads a `.bin` from `assets/firmware/control-board/` and writes `/run/hmi/upgrade-control-board.cmd`; `SyncFirmwareCommandWatcher` runs the transfer with no confirm / no version gate.

Process libraries already support:
- Bundled import at App init (`ProcessLibraryImporter.importBundled`) with same-version skip and older-version keep.
- Offline package import (`importPackageFromDirectory`) from `/var/lib/hmi/incoming/process-library/` and OTA paths, still subject to version gates.
- Source layout `assets/process-library/<model>/<version>.xlsx` with prepare → `.generated/process-library/` ship JSON + manifest. Product `model` in `/var/lib/hal/product.ini` matches Excel `supported_models` (e.g. `L1 Pro`; dir `L1_Pro`).

lws-ui exposes `make reset-process-library`: force-stop app, SQL-clear Room process rows + `processLibVersion`, relaunch for bundled re-import. This repo has no host equivalent for `/var/lib/hmi/process-library.db`.

## Goals / Non-Goals

**Goals:**

- `make upgrade-process-library`: auto-read device `model`, select matching repo library, push package, force import (no manual model env).
- Fail loudly when `model` is missing/blank or no matching model directory / supported_models entry exists in the repo.
- `make reset-process-library`: clear on-device process-library DB (lws-ui parity including user rows) via running HMI watcher and force-reimport bundled assets **without** restarting HMI.
- Document Make targets; reuse USB-SSH selection (`SN=` / `CHIPID=` / `IP=`).

**Non-Goals:**

- Changing Excel source layout, prepare pipeline, or default bundled ship contents.
- Cloud / WS / HTTP process-library push paths.
- Automatic download of process-library packages from the network.
- Requiring `make build-app` / `push-app` as part of every upgrade (watcher must exist on the board once; first adoption may need an App push).
- Preserving user custom presets across reset (lws-ui clears them; we match).

## Decisions

1. **Model source = product.ini `model` only**  
   Host reads `/var/lib/hal/product.ini` `model=` (trim). Do **not** invent a Make `MODEL=` override for the happy path (user asked for device-driven selection). Empty/missing → error. Matching is case-insensitive against product model strings; directory lookup uses spaces→underscores (`L1 Pro` → `L1_Pro`) under `app/lws_hmi/assets/process-library/`.  
   *Alternatives considered:* HAL `brand`+`model` composite — rejected; converter/`--models` already use product `MODEL` alone.

2. **Package built from git Excel source for the matched model**  
   Mirror control-board (source tree, not ship tree): pick newest `<version>.xlsx` in the matched model dir, run `convert-process-library.py` into a temp package (`manifest.json` + JSON), upload that package. Optional `PACKAGE_DIR=` may point at a pre-built package directory (must contain `manifest.json`).  
   *Alternatives considered:* Always require `.generated/` after prepare — more friction for operators editing Excel; uploading the full multi-model ship tree — larger and unnecessary when only one model matches.

3. **Device trigger = `/run/hmi` cmd watcher + force import**  
   Upload under `/run/hmi/process-library-upgrade/<basename>/`, write `/run/hmi/upgrade-process-library.cmd` with `upgrade <path>`. New watcher (firmware/alarm pattern) calls `importPackageFromDirectory` with a **force** flag that bypasses `already_installed` / `older_than_installed` / `older_version` skips (still validates hash, schema, model match). After import, reload controller presets if available.  
   *Alternatives considered:* Only drop into `incoming/` and wait for Settings UI — not operator-automation friendly. Restart HMI alone — same-version skip would no-op.

4. **Host preflight: no match → fail before upload**  
   Before SSH upload, verify a model directory (or `PACKAGE_DIR` peek) supports the device model. Error text includes the resolved model and available model dirs.

5. **Reset = cmd watcher clear + force bundled re-import (no HMI restart)**  
   Same pattern as upgrade: host writes `/run/hmi/reset-process-library.cmd` with `reset`. Watcher calls `repository.clearAll()` then `importBundled(force: true)` and reloads the controller. HMI stays up.  
   *Alternatives considered:* stop HMI + host `sqlite3` wipe + start (lws-ui adb style) — rejected for inconsistency with `upgrade-process-library` and unnecessary downtime.

6. **Target naming**  
   Exact Make names: `upgrade-process-library` and `reset-process-library` (correct spelling; user’s `blirary` typo mapped to lws-ui name).

## Risks / Trade-offs

- **[Risk] Board App lacks watcher** → Mitigation: docs/AGENTS note one-time `make build-app` + `make push-app`; script logs that HMI must be running.
- **[Risk] Force import overwrites builtins while preserving user rows** → Mitigation: keep `replaceBuiltins` semantics (user kind untouched); document that reset (not upgrade) clears user rows.
- **[Risk] product.ini `model` spelling ≠ Excel dir** → Mitigation: fail with available dirs; operators fix OEM `product.ini` / Excel naming.
- **[Risk] Reset races with open SQLite WAL** → Mitigation: stop `hmi.service` before SQL; start after.
- **[Trade-off] Per-invocation Excel convert** → Slightly slower than reusing `.generated/`, but always reflects git sources without a separate prepare step.

## Migration Plan

1. Land App watcher + force import API; push App once to boards used for this workflow.
2. Land host scripts + Make targets + docs.
3. No data migration; reset is intentional wipe. Rollback = revert scripts/App; DBs unchanged unless reset was run.

## Open Questions

- None blocking: optional later `PACKAGE_DIR=` / `LIBRARY_XLSX=` overrides can be added in implementation if useful without changing the default auto-model path.
