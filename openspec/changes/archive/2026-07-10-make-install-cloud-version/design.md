## Context

`make install` pushes a locally built APK to `/system/priv-app/LwsUI/LwsUI.apk`, reboots, runs `sync-pm-after-priv-app-install.sh` (with optional streamed `adb install` fallback), and launches the app. Published `lws-app` zips live on R2 at predictable paths (`lws-app_v{x.y.z}-beta.zip` / `lws-app_v{x.y.z}.zip`). Manifest JSON only points at the latest version; historical installs use direct zip URLs.

Full reviewed design: [`docs/make-install-cloud-version-design.md`](../../../docs/make-install-cloud-version-design.md).

**Constraints:**

- Priv-app path and permissions unchanged; cloud path reuses `install-priv-app.sh`.
- Device OTA code unchanged (no in-app downgrade).
- `RELEASE` channel for cloud install MUST come from the make CLI, not `.env` alone.
- Downgrade must not use `rm -rf /data/app/...`; PackageManager commands + state checks only.

## Goals / Non-Goals

**Goals:**

- `make install VERSION=x.y.z` downloads, validates, installs, verifies, and launches a cloud build.
- Staging vs release via CLI `RELEASE=1` (same naming as `make pack` / `make publish`).
- Downgrade: purge PM state and `package_cache` before and after install; strict PM sync; post-install verify.
- Local `make install` (no `VERSION`) behavior unchanged.

**Non-Goals:**

- Cloud firmware flash from zip `.bin`.
- New cloud API for version listing.
- Changing device `UpgradeActivity` / OTA semver rules.
- Replacing `make sync` for daily dev.

## Decisions

### 1. Extend `make install` rather than a separate mandatory target

**Choice:** Branch on `VERSION` inside existing `install` target; optional alias `install-version`.

**Alternatives:** Standalone `make install-cloud` only — rejected because operators already know `make install`; optional `VERSION` keeps one entry point.

### 2. Zip URL from pack naming convention

**Choice:** `{PUBLISH_PUBLIC_BASE_URL}/lws-app/lws-app_v{PACK_VERSION}.zip` where `PACK_VERSION` adds `-beta` unless CLI `RELEASE=1`.

**Alternatives:** Fetch manifest and match version — rejected; manifest only has latest; historical versions need predictable filenames.

### 3. Dynamic APK extraction from zip

**Choice:** List zip entries; pick sole `.apk`, or prefer name hints (`release`, `staging`, `lws`), else largest; validate with `aapt dump badging`.

**Alternatives:** Hard-code `app-release.apk` — rejected; historical packages may differ.

### 4. Download integrity: `.part` + structural validation

**Choice:** Write to `.part`, atomic rename; `unzip -t`; `aapt` on extracted APK. Optional manifest `sha512` only when version equals latest manifest.

**Alternatives:** HEAD `Content-Length` cache skip — rejected; unreliable for partial/corrupt files.

### 5. CLI `RELEASE` via dedicated env injection

**Choice:** Makefile cloud branch sets `INSTALL_RELEASE=1` only when `$(RELEASE)` is `1` on the command line; scripts read `INSTALL_RELEASE`, not sourced `.env` `RELEASE`.

**Alternatives:** Reuse `.env` `RELEASE` — rejected; causes silent wrong-channel installs.

### 6. Strict PM sync for cloud installs

**Choice:** `INSTALL_STRICT=1` disables streamed `adb install` fallback in `sync-pm-after-priv-app-install.sh`.

**Rationale:** Fallback installs to `/data/app/`, breaking priv-app replay and verify.

### 7. Downgrade purge without `/data/app` rm

**Choice:** `purge-pm-before-downgrade.sh` / `purge-pm-after-downgrade.sh` use `uninstall-system-updates`, `pm clear`, `package_cache` purge helper; assert `pm path` is absent or priv-app; fail if still `/data/app/`.

**Alternatives:** `rm -rf /data/app/*/pkg-*` — rejected; PM DB/fs inconsistency risk.

### 8. Mandatory verify before launch

**Choice:** `verify-priv-app-install.sh` checks `pm path`, `versionCode`, `versionName`, on-disk APK; cloud install aborts launch on failure.

### 9. Shared helpers

**Choice:** Factor `read_apk_version.sh` (aapt), `read_installed_version.sh` (dumpsys), `purge_package_cache_for_pkg.sh`, `assert_pm_priv_app_path.sh` under `scripts/ci/` to avoid duplication across purge/verify scripts.

## Risks / Trade-offs

- **[Risk] Strict mode fails on some ROMs** → Clear error; no silent fallback to `/data/app/`.
- **[Risk] `pm clear` wipes device data on downgrade** → Documented; debug/playback only.
- **[Risk] Historical zips lack sha512** → ZIP + aapt validation; sha512 when manifest matches.
- **[Risk] `package_cache` paths vary by ROM** → Best-effort purge helper; verify catches PM drift.
- **[Risk] Same `versionCode` for beta and release at same x.y.z** → Channel selects zip; verify checks `versionName` + package metadata.

## Migration Plan

1. Land scripts + `sync-pm` strict flag + Makefile branch.
2. Update `make help` and design doc status to implemented.
3. No device migration; operators opt in via `VERSION=`.
4. Rollback: revert Makefile branch; local install unaffected.

## Open Questions

- Whether to tighten `app-version.sh` patch max from 100 to 99 in the same change (optional follow-up).
- Exact `package_cache` glob paths per production ROM vs emulator (validate during implementation on `emulator-5554` and one physical device).
