## 1. Shared verify and staging helpers

- [x] 1.1 Expose or wrap `OtaVerify` (and HTTP download of file + `url.sig`) for arbitrary peripheral blobs staged under `/userdata/ota/control-board/` and `/userdata/ota/camera/`
- [x] 1.2 Add unit tests for peripheral verify success/failure paths (reuse system OTA signing fixtures where possible)

## 2. Host helpers: signed HTTP + device download

- [x] 2.1 Refactor `scripts/upgrade-control-board.sh` to sign selected `.bin`, serve via `ota-http-serve.py`, write `download <url>` to `/run/hmi/upgrade-control-board.cmd` (honor `OTA_HTTP_*`, `OTA_SIGNING_KEY`, `FIRMWARE_BIN=`, `SN=`/`IP=`)
- [x] 2.2 Refactor `scripts/upgrade-camera.sh` the same way for ZIP + `upgrade-camera.cmd`
- [x] 2.3 Update `SyncFirmwareCommandWatcher` / `UpgradeCameraCommandWatcher` to handle `download <url>` (download → verify → hostForce apply); optionally keep legacy `upgrade <path>` parse for one transition
- [x] 2.4 Wire Makefile help text for the changed upgrade targets

## 3. Host publish: release-only R2 upload

- [x] 3.1 Add publish script(s) (shared helper or thin wrappers) that presign-PUT firmware + `.sig` + `release.json` under `lws-hmi/control-board/` and `lws-hmi/camera/` (reuse `cloud_api_base` / token resolution / `publish_ota.py` patterns)
- [x] 3.2 Add `make publish-control-board-firmware` and `make publish-camera-firmware` (and optional `*-only` variants); always write `release.json`; support `FIRMWARE_BIN=` / `FIRMWARE_ZIP=`
- [x] 3.3 Document sibling api-server R2 key allowlist needs for the new prefixes

## 4. In-app cloud check and newest-wins

- [x] 4.1 Implement cloud manifest fetch for `…/r2/lws-hmi/control-board/release.json` and `…/camera/release.json` (always release; same API origin pin as system OTA)
- [x] 4.2 Compose bundled + cloud candidates for control-board and camera checkers; select newer typed version; prefer bundled on tie
- [x] 4.3 On Update Now for a cloud candidate: download + verify + existing Modbus / CGI applicator; keep operator confirm; never auto-apply
- [x] 4.4 Wire Auto-Check for Updates master switch (Device Information Versions last row) for CB / camera / system / Home tips; remove per-page auto-check checkboxes; no auto-apply
- [x] 4.5 Update Product Home tip compositor to use newest-wins (CB priority over camera unchanged); soft-fail to bundled-only when cloud unreachable; gate on master Auto-Check
- [x] 4.6 Ensure `FirmwareUpgradeCoordinator` mutex covers peripheral cloud download/apply vs system OTA and cross-peripheral sessions

## 5. Tests and docs

- [x] 5.1 Host/unit tests for newest-wins selection and manifest URL resolution
- [x] 5.2 Update `docs/make-commands.md`, README Make examples, and `AGENTS.md` rebuild/help rows for upgrade + new publish targets
- [x] 5.3 Smoke checklist: `make upgrade-control-board` / `upgrade-camera` (signed HTTP), publish targets against api-test/prod, Settings check + Home tip with cloud newer than bundled

See also: [SMOKE.md](./SMOKE.md)
