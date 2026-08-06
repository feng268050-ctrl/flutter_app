## Why

Warn/alarm frost dialog chrome (`WarnFrostShell`, `WarnDialogBody`, metrics, icons) lives only inside `app/lws_hmi` today, while episode policy already lives in headless `packages/cyber_alarm`. That split blocks other product HMIs from reusing the same operator warn UX without forking App files. Extracting the shared Flutter chrome into **`packages/cyber_alarm_ui`** (mirroring `cyber_upgrade_ui` beside `cyber_ota`) completes the hexagonal stack: pure engine + shared UI + App adapters.

## What Changes

- Add **`packages/cyber_alarm_ui`**: Flutter + `cyber_ui` package exporting warn frost shell, dialog body, layout metrics, severity chrome helpers, and bundled warn/info icon assets — **no** Modbus, SQLite, SFX, or App l10n inside the package.
- **Migrate** App warn presentation widgets onto `cyber_alarm_ui`; App keeps `WarnPresentation` adapter (`CyberUiWarnPresentation` → `GlobalPromptQueue`), catalog/l10n resolution, SFX, gates, and transport adapters.
- Reuse package widgets for non-`WarnPresentation` frost prompts that already share the same chrome (e.g. process-mode safety ground lock INFO prompt).
- Keep **`cyber_alarm`** pure Dart (no Flutter). Do not move episode policy, catalog model, or ports into `cyber_alarm_ui`.
- **Non-goals:** rewriting `GlobalPromptQueue`; moving product alarm ARB strings into the package; Monitor Alarm Information list/history UI; RGB / laser policy; host `make alarm` watcher.

## Capabilities

### New Capabilities

- `cyber-alarm-ui`: Shared Flutter warn frost chrome package — card-only frost shell, severity-styled dialog body (WARN vs INFO), unified metrics, injectable title/body/confirm copy and icons; Apps compose with `cyber_alarm` ports and product hosts.

### Modified Capabilities

- `cyber-alarm`: Clarify presentation boundary — modal chrome comes from `cyber_alarm_ui`; App still implements `WarnPresentation` and seeds catalog/l10n; package remains Flutter-free.
- `global-prompt-queue`: Warn frost entries continue to enqueue via `WarnPresentation`; dialog chrome SHALL come from `cyber_alarm_ui` rather than App-local widget copies.

## Impact

- **New:** `packages/cyber_alarm_ui` (Flutter + `cyber_ui`; soft/no hard dep on `cyber_alarm` for widgets that only need strings + severity style — App passes resolved copy).
- **App (`app/lws_hmi`):** path dep; replace `features/warn_alarm/presentation/warn_frost_shell.dart` / `warn_dialog_body.dart` (+ assets) with package imports; thin `CyberUiWarnPresentation` remains App-owned.
- **`packages/cyber_alarm`:** unchanged ownership of coordinator/ports/domain; docs/AGENTS note sibling UI package.
- **Docs / AGENTS:** rebuild via `make build-app` + `make push-app`; list package under `packages/`.
