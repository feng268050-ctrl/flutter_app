## 1. Shared CI helpers

- [x] 1.1 Add `scripts/ci/apk-version-read.sh` — `aapt dump badging` → `versionCode` / `versionName` / `package`
- [x] 1.2 Add `scripts/ci/installed-apk-version-read.sh` — read installed `versionCode` / `versionName` via `dumpsys package`
- [x] 1.3 Add `scripts/ci/purge-package-cache-for-pkg.sh` — best-effort `package_cache` cleanup for a package name
- [x] 1.4 Add `scripts/ci/assert-pm-priv-app-path.sh` — assert `pm path` is empty or `/system/priv-app/LwsUI/LwsUI.apk`; fail on `/data/app/`

## 2. Cloud fetch

- [x] 2.1 Add `scripts/ci/fetch-lws-app-package.sh` — CLI `INSTALL_RELEASE` channel resolution (ignore `.env` alone)
- [x] 2.2 Implement VERSION normalization and zip URL construction (`lws-app_v{pack}.zip`)
- [x] 2.3 Implement `.part` download, atomic rename, `unzip -t` validation
- [x] 2.4 Implement dynamic zip APK selection and `aapt` validation; stdout final APK path
- [x] 2.5 Optional: manifest `sha512` verify when requested version equals latest staging/release manifest

## 3. Downgrade purge

- [x] 3.1 Add `scripts/ci/purge-pm-before-downgrade.sh` — compare versionCodes; run pre-install purge when downgrading
- [x] 3.2 Add `scripts/ci/purge-pm-after-downgrade.sh` — post strict PM sync purge + second `pm clear` when downgrading
- [x] 3.3 Wire `package_cache` purge and `assert-pm-priv-app-path` in both scripts; no `/data/app` rm
- [x] 3.4 Add `scripts/ci/ensure-cloud-pm-priv-app.sh` — clear overlay before/after install for all cloud paths

## 4. Strict PM sync and verify

- [x] 4.1 Update `scripts/ci/sync-pm-after-priv-app-install.sh` — honor `INSTALL_STRICT=1` (no streamed `adb install` fallback)
- [x] 4.2 Add `scripts/ci/verify-priv-app-install.sh` — versionCode, versionName, priv-app path, on-disk APK checks

## 5. Makefile integration

- [x] 5.1 Branch `install` target on non-empty `VERSION`; export `INSTALL_STRICT=1` and CLI `INSTALL_RELEASE` for cloud path
- [x] 5.2 Chain cloud pipeline via `scripts/ci/install-cloud-version.sh`
- [x] 5.3 Extend `make help` with `VERSION=` and `RELEASE=1` examples

## 6. Documentation

- [x] 6.1 Update `docs/make-install-cloud-version-design.md` status to implemented when done
- [x] 6.2 Cross-link OpenSpec change from design doc if useful

## 7. Verification

- [x] 7.1 Emulator: `make install VERSION=1.0.36` — verify passes, app launches, `pm path` is priv-app
- [x] 7.2 Emulator: downgrade 1.0.36 → 1.0.35 — versionCode matches; pre/post purge runs
- [x] 7.3 `INSTALL_STRICT=1` blocks streamed fallback in `sync-pm-after-priv-app-install.sh` (code path + review)
- [x] 7.4 Local `make install` without `VERSION` retains streamed fallback (`INSTALL_STRICT` unset)
- [x] 7.5 `.env RELEASE=1` without CLI `RELEASE=1` still fetches beta zip (`INSTALL_RELEASE` from Make only)
- [x] 7.6 `INSTALL_RELEASE=1` + `VERSION=x.y.z-beta` fails with channel conflict
