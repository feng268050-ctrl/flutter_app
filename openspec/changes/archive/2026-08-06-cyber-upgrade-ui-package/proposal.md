## Why

Whole-device OTA and control-board firmware already ship, but their check / progress / completion UX and host “force skip version” paths are duplicated App features with no shared model. A third channel (camera program upgrade) needs the same patterns. Abstracting reusable update chrome + check/progress contracts into **`packages/cyber_upgrade_ui`** unifies operator UX and make-push force paths without folding Flutter into `cyber_ota` or Modbus into a UI package.

## What Changes

- Add **`packages/cyber_upgrade_ui`**: shared update **domain + Flutter widgets** for (1) version-check card and dialog with **pluggable check strategy**, (2) multi-phase progress card + progress bar with **caller-defined phases**, (3) configurable upgrade-complete tip presentation.
- Cover product channels via one model: **system OTA** (cloud HTTP check, multi-phase apply), **control-board firmware** (in-app offline check, single transfer phase), **camera program** (in-app offline check, single phase — channel API + UI ready; product transfer adapter may land thin/stub until camera flash is implemented).
- Shared **`UpgradePolicy`**: operator flows keep version gate + confirm; **host `make` push** (OTA / control-board / future camera) sets **skip version check** (and typically skip confirm) while still running the channel’s apply/verify path.
- **Migrate** existing System Upgrade UI (`system_ota`) and control-board bundled-firmware dialogs onto `cyber_upgrade_ui` widgets/controllers; App keeps product orchestration (safe shutdown, Modbus transfer, `cyber_ota` session, cmd watchers, l10n).
- Keep **`cyber_ota`** as the whole-device verify/extract/apply engine (no Flutter). Do not move Ed25519 / A/B apply into `cyber_upgrade_ui`.
- **Non-goals:** rewriting host scripts’ cmd-file protocol; process-library force-import UI; putting Modbus/`cyber_hal` inside `cyber_upgrade_ui`; full camera flash protocol if not already present (channel + skip-check contract only as needed for future wiring).

## Capabilities

### New Capabilities

- `cyber-upgrade-ui`: Shared Flutter path package — pluggable version check, multi-phase progress UI, completion tip, force/skip-version policy for host make-push; channel-agnostic models for system OTA, control-board, and camera program.

### Modified Capabilities

- `ota-upgrade-ui`: System Upgrade check card / progress / completion tip consume `cyber_upgrade_ui` primitives; host `make upgrade` continues to open progress-only and skip version check via shared policy.
- `startup-bundled-firmware-upgrade`: Home confirm / progress / result dialogs and host `make upgrade-control-board` skip-version path use `cyber_upgrade_ui` dialogs/progress; Modbus transfer and filename gate remain App-owned behind check/apply adapters.
- `cyber-ota`: Clarify non-goal — package remains non-UI apply engine; Apps compose it with `cyber_upgrade_ui` for presentation (no requirement change to verify/apply unless needed for progress mapping only).

## Impact

- **New:** `packages/cyber_upgrade_ui` (Flutter + `cyber_ui` for chrome; **no** hard dep on `cyber_ota` / `cyber_hal` — Apps adapt).
- **App (`app/lws_hmi`):** path dep; migrate `features/system_ota` presentation and `features/bundled_firmware` dialogs; thin adapters for cloud check, bundled offline check, host force entry; optional camera channel scaffold.
- **`packages/cyber_ota`:** unchanged ownership of manifest/HTTP/verify/apply; App maps `OtaPhase` → `cyber_upgrade_ui` phases.
- **Host make paths:** behavior preserved (`upgrade-ota.cmd` / `upgrade-control-board.cmd` skip version); App maps them to `UpgradePolicy.hostForce` (`checkVersion: false`).
- **Docs / AGENTS:** rebuild via `make build-app` + `make push-app`; note package under `packages/`.
