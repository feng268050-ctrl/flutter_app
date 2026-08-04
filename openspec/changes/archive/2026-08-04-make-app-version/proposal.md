## Why

Operators and publish/OTA flows need a single, repeatable way to read and bump the selected Flutter app version (same workflow as `lws-ui`’s `make version` / `make version-bump`). Today `app/<APP>/pubspec.yaml` and (for `lws_hmi`) `lib/app_version.dart` are edited by hand, and the build number still follows the Android 4-digit encoding (`1.0.38+1038`), which cannot express minor ≥ 10 without colliding. A host Make helper with a fixed **5-digit** build encoding and `APP=` selection unblocks consistent cloud OTA versioning and Settings/System Version display.

## What Changes

- Add **`make version`**: print combined `versionName+buildNumber` from the selected app’s `pubspec.yaml` (default `APP=lws_hmi`).
- Add **`make version-bump VERSION=x.y.z`** (optional `+build`): write version into that app’s `pubspec.yaml`, and keep product Dart constants in sync when `app/<APP>/lib/app_version.dart` exists.
- Encode build number as **5 decimal digits**: `major * 10000 + minor * 100 + patch` (e.g. `1.0.40` → `10040`). Digit budgets: major **0–9**, minor **0–99**, patch **0–99**; any bump that would exceed a field’s budget **MUST fail** with a clear error (no silent wrap).
- **BREAKING** (build number scheme): new encoding differs from the inherited lws-ui 4-digit scheme (`major*1000+minor*100+patch`). This change migrates `lws_hmi` from `1.0.38+1038` to **`1.0.40+10040`**.
- Document the targets in Makefile `help`, README Make commands, and AGENTS.md rebuild table (host-only; no firmware rebuild).

## Capabilities

### New Capabilities

- `host-app-version`: Host Make/scripts to print and bump per-APP Flutter `pubspec.yaml` version (+ optional `app_version.dart` sync) using the 5-digit build encoding and overflow checks.

### Modified Capabilities

- (none — no existing archived capability defines host version bump; `multi-app-build-select` already covers `APP=` resolution and is reused, not requirement-changed)

## Impact

- **Makefile**: new `version` / `version-bump` phony targets; `help` text.
- **New script** (e.g. `scripts/app-version.sh`): parse/encode/validate/bump; resolve `APP` via `scripts/app-select.sh`.
- **App sources**: `app/lws_hmi/pubspec.yaml` → `1.0.40+10040`; `lib/app_version.dart` → `kSystemVersion` / `kSystemVersionCode` match; future bumps via the new script for any `APP`.
- **Docs**: README, AGENTS.md.
- **Downstream**: `make-publish-ota` / cloud manifest continue to read pubspec semver; device `systemVersionCode` comparisons use the new 5-digit integer (`10040`).
