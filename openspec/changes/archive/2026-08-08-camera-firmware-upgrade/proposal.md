## Why

Camera software can only be updated today via ad-hoc vendor tools; the HMI already shows camera `appVersion` and has a stub `cameraProgram` upgrade channel, but no offline check, HTTP flash, or reboot/re-online success gate. Operators need the same in-app / host-forced path as control-board firmware: ship the newest bundled camera package, detect updates offline, push over the camera’s CGI upgrade API, then reboot and wait until the camera returns before calling success.

## What Changes

- Ship camera firmware ZIPs from `app/lws_hmi/assets/firmware/camera/` through the existing prepare/prune pipeline (keep multi-version sources in git; stage only the newest package per model into `assets/.generated/firmware/camera/`).
- Implement offline bundled-camera version check (filename SemVer + build vs live `GET /System/deviceinfo` `appVersion`) and wire Product Home tip + Settings camera-upgrade page onto `cyber_upgrade_ui` (`UpgradeChannel.cameraProgram`).
- Flash via `POST /cgi-bin/cgic_upgrade` (`multipart/form-data`, field `name="file"`) using the same raw-socket HTTP client pattern as camera OSD overlay (not Dart `HttpClient` body writes).
- After HTTP 200 on upgrade, call `PUT /System/reboot` (empty body); treat upgrade success only after the camera becomes reachable again (deviceinfo / health), not merely on CGI 200.
- Add host helper `make upgrade-camera` (mirror `upgrade-control-board`: upload package + `/run/hmi/` cmd watcher, `UpgradePolicy.hostForce`).
- Replace the stub `CameraProgramUpgradeChecker` with a real checker; extend mutex so camera flash does not race control-board / whole-device OTA.

## Capabilities

### New Capabilities

- `camera-program-upgrade`: Bundled camera firmware discovery/gate, HTTP multipart CGI flash via the camera OSD-style HTTP client, post-flash reboot + re-online success criteria, Settings/Home UX, and host force-upgrade helper.

### Modified Capabilities

- `asset-ship-prune`: Extend prepare to prune/ship newest camera firmware ZIP per model from `assets/firmware/camera/` into the generated ship tree and pubspec asset lines.
- `startup-bundled-firmware-upgrade`: Product Home auto-detect MAY also evaluate bundled camera firmware (same once-per-process tip policy as control-board); camera apply uses HTTP CGI + reboot wait instead of Modbus.
- `cyber-upgrade-ui`: Camera program progress MAY use more than one App-defined phase (e.g. transfer → reboot/wait online) while remaining channel-agnostic; completion remains App-configured (camera success does not reboot the HMI board).

## Impact

- **Assets / prepare:** `app/lws_hmi/assets/firmware/camera/` (+ README naming), `scripts/prepare-hmi-ship-assets.sh`, generated `assets/.generated/firmware/camera/`, `pubspec.yaml` ship lines.
- **App:** `features/camera_update/` (checker, coordinator, HTTP upgrader, reboot/wait), reuse/extend `CameraOsdHttpClient` / `DartCameraOsdHttpClient` for POST multipart + PUT reboot; Home bootstrap + Settings page/route; Device Info / camera settings “Camera Version” navigation; cmd watcher for host force.
- **Host:** `scripts/upgrade-camera.sh`, Makefile `upgrade-camera`, AGENTS/README rebuild notes.
- **Packages:** `cyber_upgrade_ui` (phase wording / docs if needed; no apply engine inside package).
- **Out of scope:** Cloud camera OTA; changing camera default HTTP port (remain product port `9000` unless network params expose otherwise); whole-device A/B OTA; control-board Modbus path.
