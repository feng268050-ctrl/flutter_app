## 1. OS Version stamp and host version tooling

- [x] 1.1 Add Cyber OS `/etc/os-release` (NAME/ID/VERSION/VERSION_ID) and bake via overlay / `apply-overlay`
- [x] 1.2 Expose OS Version read path in HAL and/or App sys-info (no fallback to HMI pubspec)
- [x] 1.3 Update `scripts/app-version.sh` + Makefile: default `make version` / `version-bump` → OS; `APP=` → Flutter app (no `HMI=` alias)
- [x] 1.4 Rename Flutter constants to `kHmiVersion` / `kHmiVersionCode` and update call sites (cloud, QR, Settings injections)
- [x] 1.5 Document version targets in `make help`, README, `docs/make-commands.md`, AGENTS.md

## 2. App package, sign, host upgrade

- [x] 2.1 Add script to package `/opt/hmi` install tree from `build-app` staging into `tar.gz`
- [x] 2.2 Add `make upgrade-app`: sign, HTTP serve, write `/run/hmi/upgrade-app.cmd` `download <url>`
- [x] 2.3 Make `push-app` a Make alias of `upgrade-app`; remove unsigned SCP/hot-swap path; update docs / rebuild table
- [x] 2.4 On-device apply in App (`OtaExtract` + tree install + `systemd-run systemctl restart hmi`); remove overlay `*-apply-and-restart.sh` helpers

## 3. Device HMI OTA channel and UI

- [x] 3.1 Implement `UpgradeAppCommandWatcher` for `/run/hmi/upgrade-app.cmd` + `SignedBlobFetch` verify/install/restart
- [x] 3.2 Add HMI Upgrade page (HMI Version + Process Library Version) with `cyber_upgrade_ui` check/progress
- [x] 3.3 Wire cloud check to `https://cdn.lasercyber.com/lws-hmi/app/release.json` (cloud-only; no bundled HMI version)
- [x] 3.4 Split Device Information: OS Version → System Upgrade, HMI Version → HMI Upgrade; move Process Library off System Upgrade
- [x] 3.5 Update l10n strings (OS Version / HMI Version / HMI Upgrade)
- [x] 3.6 Gate Auto-Check-on-open for HMI Upgrade; keep master switch on Device Information

## 4. Whole-device OTA retarget to OS Version

- [x] 4.1 Change `cyber_ota` / System Upgrade check to compare against OS Version
- [x] 4.2 Change `make publish` / `ota-package` naming to OS Version (keep `lws-hmi/release.json` as OS channel)
- [x] 4.3 Clarify docs that `make upgrade` is OS/rootfs-scoped; app-only uses `upgrade-app`

## 5. Cloud publish for app

- [x] 5.1 Add `make publish-app` / `publish-app-only` uploading under `lws-hmi/app/` + `release.json` (`v{semver}`)
- [x] 5.2 Document publish targets alongside peripheral firmware publish

## 6. Verification

- [x] 6.1 Host: `make version`, `APP=lws_hmi make version`, `make version-bump` OS vs app paths
- [ ] 6.2 Host: `make build-app` + `make upgrade-app` (and `make push-app` alias) on a board (signed download + service restart; no unsigned SCP)
- [x] 6.3 App: `flutter analyze` / targeted tests for version display and HMI upgrade coordinator
- [x] 6.4 Confirm System Upgrade no longer shows Process Library; HMI Upgrade shows HMI + Process Library
