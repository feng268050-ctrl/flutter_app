## Context

Today whole-device OTA UX lives in App `features/system_ota` (Settings check card + multi-phase progress on `SystemUpgradePage`) while control-board firmware UX lives in `features/bundled_firmware` (TipDialogHost confirm / progress / result). Apply engines differ: `packages/cyber_ota` (HTTP → verify → extract → A/B write) vs App Modbus FC16. Host force paths already skip version checks (`make upgrade` synthetic manifest; `make upgrade-control-board` `skipSameVersionCheck`) but each feature invents its own flag. Camera program upgrade needs the same check + single-phase progress shape and does not exist yet.

Constraint: keep `cyber_ota` Flutter-free; keep Modbus/`cyber_hal` out of shared UI packages; match CyberUI frost / Settings chrome; Flutter App API pin 3.41.9.

## Goals / Non-Goals

**Goals:**
- Introduce `packages/cyber_upgrade_ui` with shared **models + Flutter widgets** for version check (card + dialog), multi-phase progress, and completion tips.
- Pluggable **version-check strategy** so cloud HTTP, bundled-asset offline gates, and future camera offline checks share one presentation contract.
- Caller-defined **phase list** so OTA maps many phases and control-board/camera map one transfer phase.
- Shared **`UpgradePolicy`** with explicit **skip version check** (and optional skip confirm) for host `make` push entry points.
- Migrate System Upgrade and control-board dialogs onto the package; scaffold camera channel identity + UI wiring hooks.
- Preserve existing operator and host behaviors (safe shutdown, Ed25519 verify, Modbus protocol, cmd files).

**Non-Goals:**
- Moving verify/extract/`dd` or Modbus transfer into `cyber_upgrade_ui`.
- Changing `/run/hmi/*.cmd` verb/layout or host script protocols.
- Process-library force-import progress UI.
- Implementing full camera flash protocol in this change (channel + check/progress contracts + stub adapter OK).
- Merging `cyber_upgrade_ui` into `cyber_ui` or `cyber_ota`.
- Cmd-watcher generic library (optional follow-up; not required for UI abstraction).

## Decisions

### 1. Package shape: Flutter UI package + thin domain (not pure Dart like `cyber_alarm`)

**Choice:** `packages/cyber_upgrade_ui` is a **Flutter** path package depending on `cyber_ui` (and Flutter SDK). Domain types (`UpgradeChannel`, `UpgradeOffer`, `UpgradeCheckResult`, `UpgradePhase`, `UpgradeProgress`, `UpgradePolicy`, check strategy typedef/interface) live under `lib/src/` and are exported with widgets.

```
packages/cyber_upgrade_ui/
  lib/
    cyber_upgrade_ui.dart          # barrel
    src/
      domain/                  # channel, offer, policy, phase, progress, check result
      check/                   # UpgradeChecker port / strategy interface
      widgets/                 # UpgradeCheckCard, UpgradeCheckDialog,
                               # UpgradePhaseProgressCard / ProgressBody,
                               # UpgradeCompletionTip, dialog helpers
```

**Rationale:** User requirement centers on reusable cards/dialogs/progress; `cyber_ui` already owns chrome tokens. Unlike warn episodes, update UX is presentation-first with App-owned apply.

**Alternatives considered:**
- Pure Dart `cyber_upgrade_ui` + widgets only in App — rejected (duplicates OTA vs control-board chrome again).
- Fold widgets into `cyber_ui` — rejected (product update policy/phases are not generic chrome).
- Put Flutter into `cyber_ota` — rejected (engine must stay testable without Flutter).

### 2. Dependency boundary

**Choice:**
| Package | May depend on |
|---------|----------------|
| `cyber_upgrade_ui` | Flutter, `cyber_ui` |
| `cyber_upgrade_ui` | **MUST NOT** depend on `cyber_ota`, `cyber_hal`, product App |
| App | `cyber_upgrade_ui` + `cyber_ota` + Modbus/camera adapters |

App maps `OtaPhase` → `List<UpgradePhase>` / live `UpgradeProgress`. Control-board maps percent → single-phase progress. Check strategies are App (or thin adapter) implementations of `UpgradeChecker`.

**Rationale:** Same hexagonal pattern as `cyber_alarm` ports, but UI lives in-package because it is the reusable product.

### 3. Version check: strategy + two presentations

**Choice:**
- `UpgradeChecker.check({required String currentVersion, UpgradePolicy policy}) → Future<UpgradeCheckResult>`.
- When `policy.skipVersionCheck == true`, presentation/coordinator **MUST NOT** call the checker for gating (host force goes straight to apply UI).
- Widgets:
  - **`UpgradeCheckCard`** — Settings-style in-panel outcomes (idle / checking / upToDate / available / unavailable / failed) for System Upgrade.
  - **`UpgradeCheckDialog`** — confirm-style frost dialog for Home / modal channels (control-board today; camera later).

Copy is injected via parameters / builders (App supplies l10n strings), not hardcoded Chinese/English inside the package.

**Rationale:** OTA keeps card-in-page; control-board keeps dialog; one check result model.

### 4. Phases + progress UI

**Choice:**
- `UpgradePhase { id, label }` — ordered list supplied by App per channel session.
- `UpgradeProgress { activePhaseId, percent 0–100?, indeterminate?, message?, isTerminalOk, isTerminalFail, errorMessage? }`.
- **`UpgradePhaseProgressView`** (card or embeddable body): highlights active phase, shows determinate or indeterminate bar, optional per-phase checklist.
- OTA default phase ids align with operator-facing phases: download, verify, extract, write (with message for rootfs/kernel/oem), arm — mapped from `OtaPhase` in App.
- Control-board / camera: single phase e.g. `transferring`.

**Completion tip:** `UpgradeCompletionConfig` + `UpgradePostApplyAction` (`none` | `autoReboot`). Success/fail title/body plus optional notice. **OTA** uses `.autoReboot(rebootNotice:)` — show tip, then **automatic reboot** (apply engine; default ~1.5s delay for tip visibility). **Control-board** uses `.noReboot(successBody:)` (no reboot). Optional `UpgradePostApplyListener` when the App owns reboot. Widgets render tip on terminal ok/fail; App decides dialog vs inline. Do not assume reboot for every channel; do not treat OTA completion as “please reboot manually”.

**Rationale:** Matches “支持添加不同阶段” without baking OTA phases into the package enum forever.

### 5. Channels + policy for make push

**Choice:**
```dart
enum UpgradeChannel { systemOta, controlBoard, cameraProgram }

class UpgradePolicy {
  final bool checkVersion;      // false ⇒ skip gate (make push)
  final bool requireConfirm;    // false ⇒ skip dialog (make push)
}
```

Host paths:
- `make upgrade` → `systemOta` + `UpgradePolicy(checkVersion: false, requireConfirm: false)` + progress-only page.
- `make upgrade-control-board` → `controlBoard` + same skip policy + progress dialog.
- Future `make upgrade-camera` (or equivalent) → same policy shape; cmd watcher stays App-owned.

**Rationale:** Codifies existing skip behavior once; camera inherits without a third ad-hoc flag.

### 6. Migration ownership

**Choice:**
- Replace System Upgrade `_CheckUi` / progress body with `UpgradeCheckCard` + `UpgradePhaseProgressView` inside existing `SettingsScaffold` / `SettingsPanel`.
- Replace `BundledFirmwareDialogs` internals with `cyber_upgrade_ui` dialog/progress helpers (still invoked via TipDialogHost / App wrappers if host needs App-specific barrier).
- Keep `SystemOtaCoordinator`, `FirmwareUpgradeCoordinator`, Modbus handler, version filename gate, cmd watchers in App.
- Camera: add `UpgradeChannel.cameraProgram` + optional no-op/stub checker; no production flash unless already available.

**Rationale:** Smallest behavioral risk; UI unification first.

### 7. Mutex

**Choice:** Leave cross-channel mutex in App (`FirmwareUpgradeCoordinator` / OTA busy flags). Document that `cyber_upgrade_ui` does **not** serialize channels; Apps MUST continue to refuse concurrent OTA write vs control-board transfer.

**Rationale:** Mutex needs laser/safe-shutdown and Modbus knowledge; wrong layer for the UI package.

## Risks / Trade-offs

- **[Risk] Over-abstracting phases loses OTA write sub-labels** → Mitigation: `UpgradeProgress.message` (or phase subtitle) carries `writing rootfs` / kernel / oem; phases stay coarse.
- **[Risk] Dialog host coupling (`TipDialogHost` vs package `showDialog`)** → Mitigation: package exports **content widgets**; App mounts via existing TipDialogHost / Settings panel.
- **[Risk] l10n leakage into package** → Mitigation: all user-visible strings passed in; package ships English-neutral defaults only if needed for widget tests.
- **[Risk] Camera channel promised without flash** → Mitigation: spec camera as channel + check/progress contract; explicit non-goal on transfer protocol.
- **[Trade-off] No shared cmd-watcher yet** → Accept duplication until a follow-up; force path is policy-level only in this change.
- **[Trade-off] Flutter in shared package** → Host unit tests for domain stay `flutter_test`; acceptable vs splitting two packages prematurely.

## Migration Plan

1. Scaffold `packages/cyber_upgrade_ui` + widget golden/unit tests for check states and multi-phase progress.
2. Wire App path dependency; migrate System Upgrade presentation behind feature-flag-free cutover (same routes).
3. Migrate control-board dialogs; verify Home confirm + host skip-version still work.
4. Add camera channel enum + stub checker hook (no operator UI entry required until product ready).
5. Smoke: Settings check → Update Now; `make upgrade` progress-only; Home bundled confirm; `make upgrade-control-board`.
6. Rollback: revert App presentation imports to previous widgets (package can remain unused).

## Open Questions

- Exact camera check source (HTTP deviceinfo vs bundled asset) — defer to product; package only requires an `UpgradeChecker` impl.
- Whether completion tip for OTA stays inline-only or also offers a dismissible dialog — default preserve today’s inline reboot hint.
- Future shared cmd-watcher package — out of scope unless implementation proves painful.
