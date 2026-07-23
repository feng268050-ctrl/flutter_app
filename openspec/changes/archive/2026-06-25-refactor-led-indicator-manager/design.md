## Context

Side-panel RGB indicators on ynh960 are driven by YNHAPI GPIO (`GpioLedConfig`: red=4, yellow=3, green=6). Business rules live in `GpioLedHandler` → `RgbLedDecision`; hardware execution is in `GpioLedManager`, which duplicates per-color methods and hosts Dev-only escape hatches (`suspendForManualControl`, `closeAllLights`). `DevActivity` pauses business refresh and exposes manual GPIO/Light PWM test buttons — tooling that is no longer required.

Operator semantics and Modbus refresh triggers are **unchanged**; this is an internal driver refactor plus Dev cleanup.

## Goals / Non-Goals

**Goals:**

- Replace `GpioLedManager` with `LedIndicatorManager` in the same package (`common.gpio`).
- Expose one entry point: `setIndicator(LedColor color, IndicatorMode mode)`.
- Model colors (`LedColor`) and modes (`IndicatorMode`) as enums.
- Keep flash timing: `FLASH_ON_MS = 1000`, `FLASH_OFF_MS = 1000`, interval `2000 ms`.
- Preserve idempotent, synchronized GPIO writes and no-op when YNHAPI unavailable.
- Simplify `GpioLedHandler.applyRed/Yellow/Green` to single `setIndicator` calls.
- Remove all LED-related UI and lifecycle from `DevActivity` / `activity_dev.xml`.
- Remove `GpioLedHandler` manual-test pause API.

**Non-Goals:**

- Changing operator LED semantics (`RgbLedDecision` rules).
- Adding brightness/PWM support (GPIO remains on/off only).
- Renaming `GpioLedHandler` or `RgbLedDecision` (optional follow-up).
- Removing non-LED DevActivity features (video upload, record, camera ping, etc.).

## Decisions

### 1. Public API shape

```java
public enum LedColor { RED, YELLOW, GREEN }
public enum IndicatorMode { OFF, BLINK, STEADY_ON }

public final class LedIndicatorManager {
    public static void setIndicator(LedColor color, IndicatorMode mode);
    public static IndicatorMode getIndicatorMode(LedColor color); // for tests / bootstrap
    public static boolean isHardwareAvailable();
    public static void syncHardwareToCachedModes(); // replaces initAllLedStatus
}
```

**Rationale:** One method replaces nine public color methods; handler maps `RgbLedDecision.*Mode` → `IndicatorMode` directly.

**Alternative considered:** `apply(Map<LedColor, IndicatorMode>)` batch API — rejected; handler already applies three colors sequentially and batching adds little value.

### 2. Internal state

- `EnumMap<LedColor, IndicatorMode>` holds desired mode per color (default: green `STEADY_ON` matches current `greenStatus=true` boot assumption, yellow/red `OFF`).
- `setIndicator` is idempotent: if `mode` equals cached mode, return immediately.
- All mutations under `synchronized (LedIndicatorManager.class)`.

### 3. Flash tasks

- One task ID per blinking color: `ledFlash:red`, `ledFlash:yellow`.
- Shared `AbstractRxModbusTask` body parameterized by `LedColor` + GPIO pin from `LedColor.gpioPin()`.
- Entering `OFF` or `STEADY_ON` cancels that color's flash task before GPIO write.
- Green never schedules a flash task (`BLINK` is accepted but treated as no-op or assert in debug — prefer **no-op with log** to avoid crashing if mis-called).

### 4. Bootstrap on app start

`LaserApplication` currently calls `GpioLedManager.initAllLedStatus()` which toggles state to force GPIO sync. Replace with `syncHardwareToCachedModes()` that walks cached `EnumMap` and applies each color without flip tricks.

### 5. DevActivity removal scope

Remove from layout and Java:

- Entire "RGB 指示灯调试" section through Light PWM panel (lines 18–371 in `activity_dev.xml`).
- `onResume`/`onPause` LED test mode hooks.
- All LED/GPIO/Light helper methods and click handlers.
- Imports: `GpioLedConfig`, `GpioLedManager`, `GpioLedHandler`, YNHAPI (if only used for LED).

Keep: video upload, record, animation, camera ping sections.

### 6. GpioLedHandler mapping

```java
private static void applyColor(LedColor color, IndicatorMode mode) {
    LedIndicatorManager.setIndicator(color, mode);
}

private static IndicatorMode toIndicatorMode(RgbLedDecision.RedMode mode) {
    switch (mode) {
        case STEADY_ON: return IndicatorMode.STEADY_ON;
        case BLINK: return IndicatorMode.BLINK;
        default: return IndicatorMode.OFF;
    }
}
```

(Same pattern for yellow/green.)

### 7. Delete `GpioLedManager.java`

No deprecation alias — grep repo and update all references in one change.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Lost on-device LED manual test | Acceptable per product decision; operator semantics verified via unit tests + field observation |
| `initAllLedStatus` flip logic was masking stale GPIO | `syncHardwareToCachedModes` explicitly applies cached modes on cold start |
| Green `BLINK` accidentally requested | Document as unsupported; implement as no-op + debug log |
| Emulator has no YNHAPI | Keep `isHardwareAvailable()` guard; all paths no-op safely |

## Migration Plan

1. Add `LedIndicatorManager` + enums alongside `GpioLedManager`.
2. Switch `GpioLedHandler` and `LaserApplication` to new API.
3. Delete `GpioLedManager` and Dev LED UI.
4. Update unit tests (`GpioLedManagerTest` → `LedIndicatorManagerTest`).
5. Run `./gradlew test` + `make sync` on emulator for smoke (LED no-op on emulator is OK).

Rollback: revert commit; no data migration.

## Open Questions

- None blocking — green `BLINK` handled as no-op per above.
