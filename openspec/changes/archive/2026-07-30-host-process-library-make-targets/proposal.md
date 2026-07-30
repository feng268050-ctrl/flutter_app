## Why

Operators can force a control-board firmware reflash with `make upgrade-control-board`, but there is no equivalent host path to push/re-import a process library matched to the live device model. Debugging import regressions also lacks lws-ui’s `make reset-process-library` intent (clear DB + re-apply bundled library).

## What Changes

- Add `make upgrade-process-library`: SSH to the selected board, read product `model` from `/var/lib/hal/product.ini`, select the matching process-library asset from the repo (no manual model flag), upload a package, and trigger an in-app import **without** the normal same-/older-version skip (mirrors control-board “no version gate”). If the device model is empty or no repo library matches, fail with a clear error.
- Add `make reset-process-library` (spelling aligned with lws-ui; not `blirary`): write `/run/hmi/reset-process-library.cmd` so the running HMI clears process-library presets + meta and force-reimports bundled ship assets — **no** `hmi.service` restart (same cmd-watcher pattern as upgrade).
- Document both targets in Makefile `help`, README, and AGENTS rebuild notes (host-only; no firmware rebuild).

## Capabilities

### New Capabilities

- `host-upgrade-process-library`: Host Make/SSH helper that auto-selects a process-library package from device `model`, uploads it, and forces App import via a `/run/hmi` command watcher.
- `host-reset-process-library`: Host Make/SSH helper that triggers in-app clear of process-library DB + force bundled re-import via `/run/hmi/reset-process-library.cmd` (no HMI restart).

### Modified Capabilities

- (none — new host helpers; bundled import / Excel layout requirements unchanged)

## Impact

- New scripts under `scripts/` (e.g. `upgrade-process-library.sh`, `reset-process-library.sh`), Makefile targets, docs (`README.md`, `AGENTS.md`).
- Small App addition: command watcher (pattern from `SyncFirmwareCommandWatcher` / `DemoAlarmCommandWatcher`) wired in `app.dart` for force package import and in-app reset + bundled re-import.
- Reuses existing `ProcessLibraryImporter.importPackageFromDirectory` / `importBundled`, prepare/convert helpers, and USB-SSH session selection (`SN=` / `CHIPID=` / `IP=`).
- Board needs running HMI for both upgrade and reset watcher paths (one-time `make build-app` + `make push-app` when App is stale).
