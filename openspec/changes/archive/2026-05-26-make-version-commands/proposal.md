## Why

Release engineers today edit `versionName` and `versionCode` by hand in `app/build.gradle.kts`. The Flutter sibling repo (`lasercyber_mobile`) already exposes `make version` and `make version-bump VERSION=x.y.z+build` against `pubspec.yaml`; this Android repo needs the same ergonomic, validated workflow against Gradle so local bumps, pack names, and OTA semver stay consistent without hunting Kotlin DSL lines.

## What Changes

- Add **`make version`**: print the current app version as `versionName+versionCode` (e.g. `1.0.27+4123`), read from `app/build.gradle.kts`.
- Add **`make version-bump VERSION=x.y.z+build`**: validate and write both `versionName` (`x.y.z`) and `versionCode` (`build`) into `app/build.gradle.kts`.
- Enforce version shape: **major** and **minor** are single digits (`0`–`9`); **patch** is `0`–`100` (one to three digits, numeric max 100); **build** is a positive integer after `+`.
- Document targets in `make help` and align `versionCode` with the explicit build number from bumps (replacing `getGitCount()` as the published `versionCode` source).
- Optional: small shell helper under `scripts/make/` for parse/validate/update to keep the Makefile readable.

## Capabilities

### New Capabilities

- `make-version-targets`: `version` and `version-bump` Make targets, VERSION format validation, Gradle file update, and help text.

### Modified Capabilities

- `build-ci-tooling`: extend Makefile requirements to include version print/bump targets and the `versionName+versionCode` convention.

## Impact

- **Makefile**: new targets, help section, `.PHONY` entries.
- **app/build.gradle.kts**: `versionCode` assignment changes from `getGitCount()` to a literal integer maintained by `version-bump`.
- **Pack/publish**: `APP_VERSION_NAME` / `PACK_VERSION` already derive from `versionName`; unchanged aside from bump workflow.
- **OTA / SemVer**: `lws-app-ota-semver` and `device-app-version-single-source` behavior unchanged; only how developers set the numbers changes.
