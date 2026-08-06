## 1. Package scaffold

- [x] 1.1 Create `packages/cyber_alarm_ui` (Flutter package, `publish_to: none`, SDK pin compatible with App) with barrel `lib/cyber_alarm_ui.dart`
- [x] 1.2 Add path dependency on `cyber_ui`; ensure **no** dependency on `cyber_hal` or product App; do not hard-depend on `cyber_alarm` for v1 chrome widgets
- [x] 1.3 Add thin UI chrome type(s) as needed (e.g. `WarnChromeStyle` warn/info) under `lib/src/domain/`
- [x] 1.4 Copy warn/info WebP icons into package `assets/warn/` and declare them in package `pubspec.yaml`
- [x] 1.5 Wire package into workspace / App discovery the same way as other `packages/cyber_*` path packages

## 2. Shared widgets

- [x] 2.1 Move/adapt `WarnDialogMetrics` into the package (unified card width/height, insets, title fitting)
- [x] 2.2 Move/adapt `WarnFrostShell` (card-only cream frost via CyberUI blur tokens)
- [x] 2.3 Move/adapt `WarnDialogBody` with injected title/body/confirm label, WARN/INFO chrome, package asset icons, and CyberUI confirm button (preserve `beforeConfirm` hook)
- [x] 2.4 Export public API from barrel; add package README briefly stating engine stays in `cyber_alarm`
- [x] 2.5 Add package widget/unit tests for metrics, WARN vs INFO chrome, and asset load (port from App `warn_dialog_metrics_test` / related as appropriate)

## 3. Migrate App warn presentation

- [x] 3.1 Add `cyber_alarm_ui` path dependency to `app/lws_hmi/pubspec.yaml`
- [x] 3.2 Update `CyberUiWarnPresentation` to compose package `WarnFrostShell` + `WarnDialogBody`; keep `GlobalPromptQueue`, l10n/`bodyForCode`/`infoStyleForCode`, and SFX hooks App-owned
- [x] 3.3 Update `safety_ground_lock_prompt.dart` (and any other App call sites) to import `cyber_alarm_ui`
- [x] 3.4 Remove App-local `warn_frost_shell.dart` / `warn_dialog_body.dart` and duplicate `assets/warn/` entries once unused
- [x] 3.5 Retarget or relocate App tests that imported local warn widgets to the package API
- [x] 3.6 Run pinned-SDK `flutter analyze` on App + package for warn migration paths

## 4. Verification and docs

- [x] 4.1 Host/package tests green; App analyze clean under Flutter 3.41.9 pin
- [x] 4.2 Smoke checklist: rising-edge warn frost; INFO-style bypass chrome; Confirm + SFX stop; safety ground lock frost prompt; boot gate still suppresses warn during self-check
- [x] 4.3 Update AGENTS.md package map + rebuild table note for `packages/cyber_alarm_ui` (minimal, mirror `cyber_upgrade_ui`)
