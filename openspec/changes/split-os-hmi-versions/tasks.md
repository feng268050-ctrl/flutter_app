## 1. OS Version stamp and host version tooling

- [ ] 1.1 Add OS Version SoT (initial `1.0.0`) and bake into rootfs via overlay / `apply-overlay`
- [ ] 1.2 Expose OS Version read path in HAL and/or App sys-info (no fallback to HMI pubspec)
- [ ] 1.3 Update `scripts/app-version.sh` + Makefile: default `make version` / `version-bump` → OS; `APP=` → Flutter app (no `HMI=` alias)
- [ ] 1.4 Rename Flutter constants to `kHmiVersion` / `kHmiVersionCode` and update call sites (cloud, QR, Settings injections)
- [ ] 1.5 Document version targets in `make help`, README, `docs/make-commands.md`, AGENTS.md

## 2. App package, sign, host upgrade

- [ ] 2.1 Add script to package `/opt/hmi` install tree from `build-app` staging into `tar.gz`
- [ ] 2.2 Add `make upgrade-app`: sign, HTTP serve, write `/run/hmi/upgrade-app.cmd` `download <url>`
- [ ] 2.3 Make `push-app` a Make alias of `upgrade-app`; remove unsigned SCP/hot-swap path; update docs / rebuild table
- [ ] 2.4 Evolve on-device apply helper (from former push-app apply) for verified extract/install + `hmi.service` restart

## 3. Device HMI OTA channel and UI

- [ ] 3.1 Implement `UpgradeAppCommandWatcher` for `/run/hmi/upgrade-app.cmd` + `SignedBlobFetch` verify/install/restart
- [ ] 3.2 Add HMI Upgrade page (HMI Version + Process Library Version) with `cyber_upgrade_ui` check/progress
- [ ] 3.3 Wire cloud check to `https://cdn.lasercyber.com/lws-hmi/app/release.json` (cloud-only; no bundled HMI version)
- [ ] 3.4 Split Device Information: OS Version → System Upgrade, HMI Version → HMI Upgrade; move Process Library off System Upgrade
- [ ] 3.5 Update l10n strings (OS Version / HMI Version / HMI Upgrade)
- [ ] 3.6 Gate Auto-Check-on-open for HMI Upgrade; keep master switch on Device Information

## 4. Whole-device OTA retarget to OS Version

- [ ] 4.1 Change `cyber_ota` / System Upgrade check to compare against OS Version
- [ ] 4.2 Change `make publish` / `ota-package` naming to OS Version (keep `lws-hmi/release.json` as OS channel)
- [ ] 4.3 Clarify docs that `make upgrade` is OS/rootfs-scoped; app-only uses `upgrade-app`

## 5. Cloud publish for app

- [ ] 5.1 Add `make publish-app` / `publish-app-only` uploading under `lws-hmi/app/` + `release.json` (`v{semver}`)
- [ ] 5.2 Document publish targets alongside peripheral firmware publish

## 6. Verification

- [ ] 6.1 Host: `make version`, `APP=lws_hmi make version`, `make version-bump` OS vs app paths
- [ ] 6.2 Host: `make build-app` + `make upgrade-app` (and `make push-app` alias) on a board (signed download + service restart; no unsigned SCP)
- [ ] 6.3 App: `flutter analyze` / targeted tests for version display and HMI upgrade coordinator
- [ ] 6.4 Confirm System Upgrade no longer shows Process Library; HMI Upgrade shows HMI + Process Library
