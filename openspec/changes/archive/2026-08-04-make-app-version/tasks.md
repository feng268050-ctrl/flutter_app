## 1. Host version script

- [x] 1.1 Add `scripts/app-version.sh` with `print` / `bump` subcommands, sourcing `app-select.sh` for `APP=` (default `lws_hmi`) and reading/writing `app/<APP>/pubspec.yaml` `version:`
- [x] 1.2 Implement 5-digit encode/validate: `build = major*10000 + minor*100 + patch`; ranges major 0–9, minor 0–99, patch 0–99; fail on overflow or mismatched `+build` without writing files
- [x] 1.3 On bump, when `app/<APP>/lib/app_version.dart` exists, update `kSystemVersion` / `kSystemVersionCode` to match; support Darwin and GNU `sed -i`

## 2. Make targets and docs

- [x] 2.1 Wire `make version` and `make version-bump` (require `VERSION=`) in the Makefile; pass through `APP`; add both to `.PHONY` and `help`
- [x] 2.2 Document targets in README Make commands and AGENTS.md rebuild table (host-only: exercise `make version` / `make version-bump`; no firmware rebuild)

## 3. Migrate lws_hmi to 1.0.40

- [x] 3.1 Set `app/lws_hmi/pubspec.yaml` to `version: 1.0.40+10040` and `lib/app_version.dart` to `kSystemVersion = '1.0.40'` / `kSystemVersionCode = 10040` (5-digit encoding)

## 4. Verification

- [x] 4.1 Smoke-test `make version` prints `1.0.40+10040`; exercise overflow cases (`1.0.100`, `1.100.0`, `10.0.0`) and mismatched `+build` without leaving files dirty
- [x] 4.2 Confirm `APP=` selects the correct pubspec; confirm a temporary bump+restore (or script unit path) syncs Dart constants when present
