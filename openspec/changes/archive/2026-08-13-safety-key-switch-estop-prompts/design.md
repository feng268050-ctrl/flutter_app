## Context

Quick / Engineer already host `KeySwitchOffPrompt` and `EmergencyStopPrompt` as non-logged Warn Frost dialogs (`WarnFrostShell` + `WarnDialogBody`). Today both use **INFO** chrome (`infoStyle: true`). The Misc toggle `showKeySwitchAlarm` gates whether a **physical key-off edge** shows `KeySwitchOffPrompt`; when the toggle is off, that edge is silent, and Enable Laser key-off falls back to `OperationFailedDialogHost` (dark tip). E-stop was recently moved to yellow INFO frost with no Settings switch.

`cyber_alarm_ui` already distinguishes **WARN** (red siren + red title) vs **INFO** (orange info icon + black title). This change only selects chrome and routing; it does not add a new Settings control or logged alarm codes.

## Goals / Non-Goals

**Goals:**

- Key-off **edge** uses WARN chrome when Misc Show Key Switch Alarm is on; INFO chrome when that toggle is off (Laser Enable session state MUST NOT gate the edge).
- Enable Laser while key is still off always uses INFO chrome (even if the toggle is on and a WARN was already shown/dismissed).
- E-stop edge and Enable Laser while E-stop is active always use INFO chrome. No Misc gate. No WARN path.
- Confirm or interlock restore (key ON / E-stop released) dismisses the matching prompt.
- **SFX:** WARN chrome may play warn-loop SFX; INFO (yellow) chrome MUST be silent (no `WarnAlarmSound`).
- At most one of these frosts is visible.

**Non-Goals:**

- New Misc / Advanced Settings switches.
- Logging key-off / E-stop prompts as alarm-history rows or coordinator episodes (`C*` codes).
- Changing H022/W001 e-stop suppression (`estop-comm-alarm-suppress`).
- Changing laser E-stop **logged** alarm copy (`laserEmergencyStopAlarmTitle`).

## Decisions

### 1. Chrome mapping (WARN vs INFO)

- **WARN** (`infoStyle: false` / `WarnChromeStyle.warn`): key-off **rising edge** and Misc `showKeySwitchAlarm == true`.
- **INFO** (`infoStyle: true`): all other cases in this policy (key-off edge with toggle off; Enable Laser blocked by key-off; any E-stop prompt).

Rationale: red is reserved for “operator opened the keyed interlock while asking for an alarm.” Yellow is the instructional block for “reset then retry,” including Enable Laser preflight.

Alternative considered: WARN whenever Laser Enable is armed — rejected; the user gates red on the Misc toggle, not on laser session.

### 2. Two presentation entries on `KeySwitchOffPrompt`

Keep one host class; split show paths:

- `maybeShowForKeyOffEdge(...)` — physical `DeviceControlSafetyEvent.keySwitchOff`. Chooses WARN vs INFO from Misc. Latch once per key-off until restore.
- `presentLaserEnableKeyOffBlock(...)` — Laser Enable preflight. Always INFO. Does not require the Misc toggle. If a WARN frost for this key-off is still showing, dismiss it first so Enable Laser INFO replaces it.

`EmergencyStopPrompt` stays a single INFO host for both edge and Enable Laser (no chrome split).

Alternative considered: two widgets (`KeySwitchOffAlarm` vs `KeySwitchOffWarning`) — rejected; copy and restore lifecycle are shared.

### 3. Misc OFF still shows an INFO frost on key-off edge

When `showKeySwitchAlarm` is false, key-off is **not** silent: show INFO frost (same copy). Enable Laser while key-off is the same INFO frost (latch / replace so it is not double-shown).

This replaces the current “edge silent + Operation-failed tip on Enable Laser” split.

### 4. Dismiss and SFX

- Confirm → `beforeConfirm` stop SFX → pop.
- `keySwitchRestored` / `emergencyStopCleared` → `reset()` / `dismissIfShowing()` (existing).
- WARN and INFO share `WarnAlarmSound` episode codes already used (`key_switch_off_prompt`, `emergency_stop_prompt`).
- `suppressKeySwitchOffSafetyPrompt` remains so Enable Laser preflight does not also enqueue a second **edge** presentation in the same gesture.

### 5. Copy

Reuse existing ARBs. No new strings unless a test needs a stable fallback.

## Risks / Trade-offs

- [Misc OFF now pops on every key-off] → Matches the requested safety floor; toggle only upgrades edge chrome to red, it does not hide prompts.
- [Enable Laser INFO while WARN still up] → Replace WARN with INFO so two frosts never stack.
- [Logged H029 laser E-stop vs this INFO prompt] → Distinct paths; this change does not alter coordinator presentation.

## Migration Plan

Ship with App (`make build-app` / `make push-app`). No persistence / OEM migration. Rollback is revert of the prompt routing commits.

## Open Questions

- None. Title/body copy already landed for E-stop INFO; key-switch copy stays as shipped.
