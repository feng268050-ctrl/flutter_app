## Context

Warn episode policy already lives in headless `packages/cyber_alarm`. Modal frost chrome (`WarnFrostShell`, `WarnDialogBody`, `WarnDialogMetrics`, warn/info icons) and the `WarnPresentation` host (`CyberUiWarnPresentation`) still live under `app/lws_hmi/lib/features/warn_alarm/presentation/`. Process-mode `safety_ground_lock_prompt.dart` reuses the same shell/body outside the coordinator path. Sibling pattern: `packages/cyber_upgrade_ui` (Flutter + `cyber_ui`) beside pure-Dart `cyber_ota`.

Constraints: Flutter App API pin 3.41.9; keep `cyber_alarm` Flutter-free; keep Modbus / SQLite / SFX / product ARB out of the UI package; preserve `GlobalPromptQueue` as the sole modal FIFO for warn frost.

## Goals / Non-Goals

**Goals:**
- Introduce `packages/cyber_alarm_ui` with shared warn frost widgets + metrics + bundled icons.
- Migrate App warn presentation and other frost prompts that already use the same chrome onto the package.
- Keep App ownership of `WarnPresentation` → `GlobalPromptQueue`, catalog/l10n, SFX, gates, and transport adapters.
- Document the three-layer stack: `cyber_alarm` (engine) + `cyber_alarm_ui` (chrome) + App (adapters/host).

**Non-Goals:**
- Moving `WarnAlarmCoordinator`, ports, or catalog model into `cyber_alarm_ui`.
- Putting `GlobalPromptQueue` or product guidance prompts into the package.
- Moving Monitor Alarm Information / history UI or RGB / laser policy.
- Merging warn frost into generic `cyber_ui` `showCyberDialog` (card-only cream frost remains product warn chrome).
- Changing episode recover/ack policy or boot self-check gate behavior.

## Decisions

### 1. Package shape: Flutter UI beside headless engine (mirror `cyber_upgrade_ui`)

**Choice:** `packages/cyber_alarm_ui` is a Flutter path package depending on `cyber_ui` (+ Flutter SDK). Layout:

```
packages/cyber_alarm_ui/
  lib/
    cyber_alarm_ui.dart
    src/
      domain/          # thin UI chrome types (e.g. WarnChromeStyle)
      widgets/         # WarnFrostShell, WarnDialogBody, WarnDialogMetrics
  assets/warn/         # alarm_warn_icon.webp, alarm_info_icon.webp, …
```

**Rationale:** Matches the established “engine package + UI package” split. Warn chrome is reusable product UX, not generic CyberUI.

**Alternatives considered:**
- Fold frost into `cyber_ui` — rejected (severity icons + warn metrics are product alarm UX).
- Put Flutter into `cyber_alarm` — rejected (breaks pure-Dart / host unit tests).
- Only extract widgets but leave assets in App — rejected (second product would still fork icons).

### 2. Dependency boundary

**Choice:**

| Package | May depend on |
|---------|----------------|
| `cyber_alarm` | Dart only (unchanged) |
| `cyber_alarm_ui` | Flutter, `cyber_ui` |
| `cyber_alarm_ui` | **MUST NOT** depend on `cyber_hal`, product App, SQLite, or hard-require `cyber_alarm` for chrome widgets |
| App | `cyber_alarm` + `cyber_alarm_ui` + adapters |

Widgets take **injected strings** (title, body, confirm label) and a chrome flag (`infoStyle` / `WarnChromeStyle`). App resolves catalog + `AppLocalizations` before calling into the package.

**Optional soft dep:** If a thin mapping from `AlarmSeverity` is useful later, App maps it; do not force `cyber_alarm` into `cyber_alarm_ui` pubspec for v1.

**Rationale:** Same hexagonal inject-copy pattern as `cyber_upgrade_ui`.

### 3. Confirm button: CyberUI, not App `HmiButton`

**Choice:** Package `WarnDialogBody` uses `CyberButton` (or equivalent CyberUI primary/hero control) sized by `WarnDialogMetrics`, with optional `beforeConfirm` for App SFX stop + click-sound registry hooks passed from the App host. Do **not** import `lws_hmi` `HmiButton`.

**Rationale:** Package cannot depend on the product App. Visual parity is preserved via shared metrics (confirm min width / height / label size) already tuned to hero Confirm.

**Alternatives considered:**
- `confirmBuilder` only — viable escape hatch, but default CyberButton keeps second Apps consistent.
- Keep `HmiButton` via callback widget from App always — more boilerplate for every call site.

### 4. Presentation host stays in App

**Choice:** `CyberUiWarnPresentation` remains under App `features/warn_alarm/presentation/`. It implements `WarnPresentation`, enqueues on `GlobalPromptQueue`, resolves l10n/`bodyForCode`/`infoStyleForCode`, and builds `WarnFrostShell` + `WarnDialogBody` from `cyber_alarm_ui`.

**Rationale:** Host is tightly coupled to App global prompt + product hooks (SFX, dangerous-ops INFO bypass, dynamic A001 body). Extracting it would pull `GlobalPromptQueue` into the package or invent a second host abstraction without clear second consumer yet.

### 5. Assets move with the package

**Choice:** Ship warn/info WebP icons as package assets; `WarnDialogBody` references `package:cyber_alarm_ui/...` asset paths. Remove duplicate App `assets/warn/` entries once migrated (or leave thin re-exports only if tests need them — prefer delete).

**Rationale:** Chrome and icons travel together for reuse.

### 6. Shared frost reuse sites

**Choice:** Update `safety_ground_lock_prompt.dart` (and any other App call sites of `WarnFrostShell` / `WarnDialogBody`) to import `cyber_alarm_ui`. Delete App-local widget source files after migration; move/adjust widget tests into the package (or keep thin App smoke tests that import the package).

**Rationale:** Proposal requires replacing App usage, not only adding a parallel package.

### 7. Docs / AGENTS

**Choice:** Add `cyber_alarm_ui` to AGENTS package map and rebuild table (same as `cyber_upgrade_ui`: `make build-app` / `make push-app`; host `flutter test` in package).

## Risks / Trade-offs

- **[Risk] Visual drift vs `HmiButton` hero Confirm** → Mitigation: match existing `WarnDialogMetrics` sizes; screenshot/manual compare on board; keep `beforeConfirm` + click sound behavior in App host.
- **[Risk] Asset path / pubspec omission breaks icons on device** → Mitigation: declare assets in package `pubspec.yaml`; App path-depends package; widget test loads package assets.
- **[Risk] Over-extracting host into package** → Mitigation: explicit non-goal; keep `CyberUiWarnPresentation` in App.
- **[Trade-off] No `cyber_alarm` type coupling in UI package** → App maps severity → `infoStyle`; slightly more glue, cleaner boundaries.

## Migration Plan

1. Scaffold `packages/cyber_alarm_ui` (pubspec, analysis_options, barrel, assets).
2. Move/adapt `WarnDialogMetrics`, `WarnFrostShell`, `WarnDialogBody` (+ icons); swap Confirm to CyberUI.
3. Add package widget tests (metrics + body chrome); run `flutter test` in package.
4. Point App `CyberUiWarnPresentation`, `safety_ground_lock_prompt`, and tests at package; remove App-local copies / assets.
5. Wire App `pubspec.yaml` path dep; `flutter analyze` / App tests.
6. Update AGENTS.md package map + rebuild note.
7. Board smoke: rising-edge warn dialog, INFO-style bypass, Confirm + SFX stop, safety ground lock prompt.

**Rollback:** Revert path dep and restore App-local widgets from git; no on-device schema change.

## Open Questions

- None blocking — Confirm uses CyberButton by default; optional `confirmBuilder` only if board parity fails during apply.
