## 1. Package scaffold

- [x] 1.1 Create `packages/cyber_upgrade_ui` (Flutter package, `publish_to: none`, SDK pin compatible with App) with barrel `lib/cyber_upgrade_ui.dart`
- [x] 1.2 Add path dependency on `cyber_ui`; ensure **no** dependency on `cyber_ota` or `cyber_hal`
- [x] 1.3 Add domain types: `UpgradeChannel` (systemOta / controlBoard / cameraProgram), `UpgradeOffer`, `UpgradeCheckResult`, `UpgradePhase`, `UpgradeProgress`, `UpgradePolicy`, `UpgradeCompletionConfig`
- [x] 1.4 Define pluggable `UpgradeChecker` (or equivalent strategy) interface returning structured check results
- [x] 1.5 Wire package into workspace / App discovery the same way as other `packages/cyber_*` path packages

## 2. Shared widgets

- [x] 2.1 Implement `UpgradeCheckCard` for Settings-style in-panel check states (idle / checking / upToDate / available / unavailable / failed) with injected copy and Update Now / later actions
- [x] 2.2 Implement `UpgradeCheckDialog` content (confirm/cancel) suitable for TipDialogHost / frost prompt mounting
- [x] 2.3 Implement multi-phase progress view (phase list + determinate/indeterminate bar + optional message)
- [x] 2.4 Implement completion tip presentation for terminal success/failure (App-configured title/body/hint)
- [x] 2.5 Add package widget/unit tests for check states, single-phase vs multi-phase progress, and force policy not gating UI when `checkVersion: false`

## 3. Migrate system OTA UI

- [x] 3.1 Add `cyber_upgrade_ui` path dependency to `app/lws_hmi/pubspec.yaml`
- [x] 3.2 Replace System Upgrade check body with `UpgradeCheckCard`; keep `cyber_ota` manifest check + `OtaManifestUrl` in App adapter
- [x] 3.3 Map `OtaPhase` / `OtaProgress` → `UpgradePhase` list + `UpgradeProgress`; replace progress body with `cyber_upgrade_ui` phase progress + completion tip (preserve download/verify/extract/write/arm labels and write sub-messages)
- [x] 3.4 Map host `make upgrade` / progress-only entry to `UpgradePolicy(checkVersion: false, requireConfirm: false)` so version gate is skipped
- [x] 3.5 Keep `SystemOtaCoordinator`, safe shutdown, cmd watcher, and WS handlers App-owned; remove duplicated private check-state chrome once widgets land
- [x] 3.6 Run `flutter analyze` (pinned SDK) on App + package for OTA migration paths

## 4. Migrate control-board firmware UI

- [x] 4.1 Implement control-board offline `UpgradeChecker` adapter wrapping existing filename HW/SW gate (`BundledFirmwareVersionGate`)
- [x] 4.2 Replace `BundledFirmwareDialogs` confirm / progress / success / fail with `cyber_upgrade_ui` dialog + single-phase progress + completion primitives (still mount via TipDialogHost; keep `bundledFirmware*` l10n)
- [x] 4.3 Map `make upgrade-control-board` / `skipSameVersionCheck` to `UpgradePolicy(checkVersion: false, requireConfirm: false)`
- [x] 4.4 Keep Modbus `ControllerUpgradeHandler`, asset discovery, and mutex (`FirmwareUpgradeCoordinator`) in App
- [x] 4.5 Verify Home confirm still required for operator path; host path still skips confirm + version gate

## 5. Camera channel scaffold

- [x] 5.1 Expose `UpgradeChannel.cameraProgram` in App wiring hooks (stub checker and/or no UI entry) so future offline camera upgrade can reuse the same card/dialog/progress API
- [x] 5.2 Document in package README or short App comment that camera flash protocol is out of scope for this change

## 6. Verification and docs

- [x] 6.1 Host/package tests green; App analyze clean under Flutter 3.41.9 pin
- [x] 6.2 Smoke checklist: Settings Check → Update Now; `make upgrade` progress-only skip-version; Home bundled confirm + progress; `make upgrade-control-board` skip-version
- [x] 6.3 Update AGENTS/README package map only if required for new `packages/cyber_upgrade_ui` mention (minimal)
