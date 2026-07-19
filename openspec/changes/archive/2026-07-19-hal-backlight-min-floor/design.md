## Context

`Backlight.setBrightnessPercent(0)` and the Demo slider at minimum currently write sysfs `brightness=0`, blacking out a touch-only HMI. Operators still need a logical “0% = dimmest” control; the bug is mapping that to absolute hardware zero.

Kind C `change-backlight` helpers were retired; HAL (`LinuxSysfsBacklight`) owns sysfs apply + `/var/lib/hmi/backlight-brightness` persist. The hardware floor belongs in the **percent↔device remap**, not in API/UI clamp.

## Goals / Non-Goals

**Goals:**

- API and UI remain **0–100** inclusive (logical percent).
- HAL never writes sysfs `brightness=0` on set / preference apply.
- Logical 0 maps to a small non-zero hardware floor (“冗余”); logical 100 maps to `max_brightness`.
- Get reverse-maps so the hardware floor reads back as logical 0.
- Persist stores logical percent (including 0).

**Non-Goals:**

- Changing media volume.
- Forbidding logical 0 in API/UI.
- Panel power-off / blanking API.
- Per-SKU optical calibration beyond a single linear remap.
- Reintroducing retired `change-backlight` helpers.

## Decisions

### D1 — Logical 0–100; hardware floor via remap

**Choice:** Callers use `clampPercent` (0–100). Mapping uses `kBacklightHwFloorPercent` (default **5**): logical 0 → `max(1, round(max * 5/100))`, logical 100 → `max`, linear in between. Reverse map for get.

**Why not clamp API/UI to 5–100:** User-facing “0” is expected; the redundancy is a hardware safety margin, not a missing slider tick.

**Why 5% of max:** Visible enough on ynh960-class PWM panels; easy to retune via the named constant.

### D2 — Remap helpers, not a second clamp API

**Choice:** `backlightPercentToDevice` / `backlightDeviceToPercent` (plus floor device helper). Do **not** expose `clampBacklightPercent` that rejects 0. Shared `clampPercent` stays for volume and backlight logical clamp.

### D3 — Persist logical percent (including 0)

**Choice:** Preference file stores 0–100 as requested. Apply remaps to hardware. Restoring logical `0` leaves the panel at the hardware floor, not black.

**Why not rewrite stored 0→5:** That would lie about the operator’s setting and fight the API contract.

### D4 — Demo slider `min: 0`

**Choice:** Brightness UI minimum stays 0; volume unchanged.

### D5 — Stub is logical-only

**Choice:** `StubBacklight` stores 0–100 with `clampPercent`; no hardware floor simulation required (optional later for emulator realism).

## Risks / Trade-offs

- **[Risk]** At logical 0 the panel is still faintly lit → **Accept**; that is the product intent.
- **[Risk]** External `echo 0 > brightness` still blacks the panel → **Mitigation:** out of scope; supported path is HAL/Demo.
- **[Risk]** Legacy mid-range values shift slightly after remap (old linear 0–max vs new floor–max) → **Mitigation:** accept small discontinuity; mid values remain approximately correct.

## Migration Plan

1. Ship remap in app bundle (`make build-app` / `push-app`).
2. Existing preference `0` now correctly means “dimmest usable” instead of black.
3. Rollback: revert app; preference schema unchanged (integer 0–100).

## Open Questions

- None blocking; `kBacklightHwFloorPercent` can be retuned after device check.
