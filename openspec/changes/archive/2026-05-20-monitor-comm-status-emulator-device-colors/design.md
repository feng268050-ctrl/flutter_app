## Context

`WarnInfoFragment` binds three Comm Status tiles (Pump, Gun, Feeder) in `fragment_warn_info.xml` with:

```xml
android:checked="@{statusReady ? !deviceStatus.isXxxCommunicationAlarm : false}"
```

Unchecked maps to `@mipmap/check_none` (red) via `checkbox_selector_show`. The prior `offline-alarm-status-readiness` change correctly blocks false green when offline, but Comm Status tiles now always appear red without hardware—which is noise on emulator and signal on device.

`AndroidEmulatorUtils.isLikelyEmulator()` already centralizes AVD detection elsewhere in the app.

## Goals / Non-Goals

**Goals:**

- Comm Status tiles show **gray** when comm is absent or status is not ready **on emulator**.
- Comm Status tiles show **red** when comm is absent or status is not ready **on real device (YNH)**.
- When `statusReady` is true and the comm alarm bit is clear, show **green** on both platforms.
- Keep temperature and other alarm tiles on existing readiness + red-unchecked behavior.

**Non-Goals:**

- Changing Modbus polling, `statusReady` validity rules, or alarm bit definitions.
- Adding a global “device connected” abstraction across all Monitor screens.
- Redesigning Comm Status card layout or strings.

## Decisions

1. **Three-state indicator for Comm Status only (not a boolean `CheckBox` alone)**

   - Use a small binding helper or `@BindingAdapter` that sets the checkbox button drawable (or swaps to an `ImageView`) based on `{emulator, statusReady, commAlarm}`.
   - Rationale: `CheckBox` only has checked/unchecked; gray needs a third visual. Alternatives: custom `View` with three drawables (acceptable); tri-state `CheckBox` via `android:button` selector with `state_activated` (possible if we map activated=gray).
   - **Preferred:** `@BindingAdapter` on the three Comm Status checkboxes setting `button` drawable to `check_succeed` / `check_none` / `check_neutral` (new gray asset) based on computed enum or int state.

2. **Expose `emulator` boolean from `WarnInfoFragment`**

   - Set `binding.setEmulator(AndroidEmulatorUtils.isLikelyEmulator())` once in `initData()`.
   - Rationale: matches existing emulator utilities; no new Build.* duplication in XML.

3. **Comm “no comm” definition**

   - **Not ready** (`!statusReady`): treat as no comm for display purposes.
   - **Ready + alarm bit set** (`isLaserCommunicationAlarm`, `isGunCommunicationAlarm`, `isWireFeederCommunicationAlarm`): fault on device, neutral on emulator only when the alarm indicates missing comm (same as today’s alarm semantics).
   - **Ready + alarm clear**: green on both platforms.

4. **Do not change non-comm tiles**

   - Temperature tiles keep `statusReady && dataReady` gating and red unchecked when not ready.
   - Rationale: user request is scoped to Comm Status cards only.

## Risks / Trade-offs

- **[Risk] Emulator mis-detection on unusual builds** → **Mitigation:** Reuse `AndroidEmulatorUtils`; same heuristic as Modbus skip and status bar hide.
- **[Risk] Gray asset missing or inconsistent with design** → **Mitigation:** Add `check_neutral` mipmap aligned with existing `check_succeed` / `check_none` size (36dp).
- **[Trade-off] BindingAdapter vs inline expression** → BindingAdapter keeps XML readable and testable in one place.

## Migration Plan

1. Add gray drawable asset and binding adapter (or helper class).
2. Add `emulator` variable to `fragment_warn_info.xml` data section.
3. Update three Comm Status `CheckBox` elements to use adapter; remove simple `checked` ternary for those tiles.
4. Manual verify on AVD: offline → gray comm icons; simulated alarm bit → gray.
5. Manual verify on device (or non-emulator build): offline → red; comm alarm → red; healthy → green.
6. Rollback: revert layout + fragment + adapter + asset.

## Open Questions

- Should gray also apply on emulator when `statusReady` is true but comm alarm is set (user said “未有通讯”—likely both offline and alarm)? **Assumption: yes**—emulator never treats missing comm as a fault; always gray when not healthy/green.
