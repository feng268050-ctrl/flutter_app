## 1. Ship assets and prepare prune

- [ ] 1.1 Add `app/lws_hmi/assets/firmware/camera/README.md` documenting `{MODEL}-v{SEMVER} build{YYYYMMDD}.zip` naming, multi-version source tree, and prepare/ship behavior
- [ ] 1.2 Ensure current camera ZIP(s) match the naming rule and remain under the source tree (not hand-edited `.generated`)
- [ ] 1.3 Extend `scripts/prepare-hmi-ship-assets.sh` to prune newest-per-model camera ZIPs into `assets/.generated/firmware/camera/`, fail on invalid `.zip` names, and rewrite pubspec generated-ship-assets lines to include the camera ship dir
- [ ] 1.4 Verify `make prepare-app-assets` stages only the newest ZIP per model

## 2. Version parse, assets, and checker

- [ ] 2.1 Add bundled camera filename / `appVersion` SemVer+build parse helpers and comparison (`>` gate)
- [ ] 2.2 Add ship-asset discovery helpers for `assets/.generated/firmware/camera/` (list / select newest / load bytes)
- [ ] 2.3 Replace stub `CameraProgramUpgradeChecker` with real offline check against `CameraDeviceInfoCache` + bundled assets
- [ ] 2.4 Unit-test parse, compare, asset select, and checker outcomes (newer / same / unreachable)

## 3. Camera HTTP flash + reboot client

- [ ] 3.1 Extend `CameraOsdHttpClient` / `DartCameraOsdHttpClient` with multipart POST (field `file`, octet-stream) using the same single-write Socket framing as OSD
- [ ] 3.2 Support empty-body `PUT /System/reboot` via the same client; keep Basic Auth header casing
- [ ] 3.3 Implement camera upgrade applicator: POST `/cgi-bin/cgic_upgrade` → require 200 → PUT reboot → require 200 → poll wait-online (deviceinfo/health) with timeout
- [ ] 3.4 Unit/widget tests with fake HTTP client covering success, CGI failure, reboot failure, and wait timeout

## 4. Coordinator, mutex, and UX

- [ ] 4.1 Add `CameraProgramUpgradeCoordinator` (offer evaluate, operator run, host-force entry, progress stream, phases: transfer / reboot / waitOnline)
- [ ] 4.2 Wire `FirmwareUpgradeCoordinator` (or equivalent) so camera sessions mutex with control-board and whole-device OTA
- [ ] 4.3 Add `CameraProgramUpgradePage` on `cyber_upgrade_ui` (check card + progress + completion, no HMI board reboot)
- [ ] 4.4 Navigate Device Information / IP Camera “Camera Version” to the new page; add routes/l10n as needed
- [ ] 4.5 Extend Home `BundledFirmwareBootstrap` for camera tip (once per process; control-board tip priority)

## 5. Host force path and docs

- [ ] 5.1 Add `scripts/upgrade-camera.sh` + Makefile `upgrade-camera` (`FIRMWARE_ZIP=` override; source tree select newest)
- [ ] 5.2 Add `/run/hmi/upgrade-camera.cmd` watcher mapping to host-force coordinator entry (upload dir under `/run/hmi/`)
- [ ] 5.3 Update AGENTS.md / README / make-commands as needed for `upgrade-camera` and rebuild notes
- [ ] 5.4 Run focused Flutter tests / analyze for touched App packages
