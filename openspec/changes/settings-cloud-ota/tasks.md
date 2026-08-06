## 1. cyber_ota channel manifest

- [x] 1.1 Update `OtaManifest.fromJson` to accept publish `url` when `package_url` is absent; keep `package_url` precedence; default `.sig` from resolved archive URL
- [x] 1.2 Extend `packages/cyber_ota` unit tests for publish-shaped JSON, `package_url` precedence, and missing-both failure
- [x] 1.3 Extend `checkForUpdate` / session tests so Fake HTTP returns publish-shaped channel JSON and reports newer correctly

## 2. Settings Device Information OTA (interim wiring — superseded by §5 UI)

- [x] 2.1 Audit Check for Updates UX: unavailable (cloud off / no pinned API) vs check failed vs up to date vs update available — fix any false “up to date”
- [x] 2.2 Confirm → `startCloudUpdateFlow` path; ensure safe shutdown + dedicated upgrade page before cloud download
- [x] 2.3 Auto-check: on enable / tab arm run one check; keep periodic interval; prompt only, never auto-apply
- [x] 2.4 Verify `OtaManifestUrl` tier → `staging.json` / `release.json` and artifact `lws-hmi`; fix join if `/view/` path wrong vs Worker

## 3. WebSocket parity

- [x] 3.1 Confirm `handleWsCheckUpdate` / `handleWsUpdateSystem` use the same `OtaManifest` parser (payload with `url` works)
- [x] 3.2 Confirm `device.update_progress` still maps from coordinator progress during cloud download/write

## 4. Docs and verification

- [x] 4.1 Add `openspec/changes/settings-cloud-ota/smoke.md` (publish staging newer than device → Settings check → confirm → upgrade page → verify/apply)
- [x] 4.2 Note same-version `-beta` vs release compare caveat in smoke or make-commands if missing
- [x] 4.3 Host: `dart test` / `flutter test` for touched `cyber_ota` + App OTA tests
- [ ] 4.4 Board smoke against a real `make publish` staging object; record `/view/` GET result (open question)
- [x] 4.5 Update `smoke.md` for Device Information → OTA sub-page → Update Now → CyberUI progress page

## 5. Device Information → System Upgrade (full-height card)

- [x] 5.1 System Upgrade: one `SettingsPanel` fills remaining height; version + in-card check / Update Now; apply progress on same card
- [x] 5.2 Device Information: System Version nav row opens System Upgrade; Check + auto-check checkbox on upgrade page
- [x] 5.3 Coordinator: `alreadyOnUpgradePage` for Update Now; named route `progressOnly` for `make upgrade` / cleared-stack
- [x] 5.4 Check outcomes in content card (no dialogs); progress-only hides check footer
- [x] 5.5 l10n for System Upgrade idle hint / Update Now / Later as needed (`make l10n`)
- [x] 5.6 Host flutter analyze + update smoke.md
