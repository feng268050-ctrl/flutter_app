## Context

The laser-enable **Important Reminder** dialog (`ReminderExactDialog`, layout `dialog_reminder.xml`) is opened from quick mode and engineer mode via `ReminderExactBuilder`. Card 2 already shows mode-specific **copy** via `LaserEnableReminderCopy.nozzleTipResId(processModel)`, but its `ImageView` still uses a static `@mipmap/open_laser_icon2` for all models.

Card 3 already demonstrates the preferred pattern: `FocusScaleRefImageLoader.bind(imageView, DeviceModelConfig.getFocusScaleRef())` loads from `res/drawable-nodpi/fsr_*.png` at runtime with a blank fallback when missing.

Four source illustrations are ready on the developer machine:

| Source file (`Desktop/LwsUI/`) | Target drawable | Models |
|-------------------------------|-----------------|--------|
| `nozzle-weld.png` | `nozzle_weld.png` | `CONTINUOUS_WELDING`, `POINT_WELDING` |
| `nozzle-cut.png` | `nozzle_cut.png` | `HAND_CUT`, `CNC_CUT` |
| `nozzle-weld-path-clean.png` | `nozzle_weld_path_clean.png` | `WELD_CLEAN` |
| `nozzle-ultra-wide-clean.png` | `nozzle_ultra_wide_clean.png` | `WIDTH_CLEAN` |

## Goals / Non-Goals

**Goals:**

- Show a mode-appropriate nozzle illustration on reminder card 2 when laser enable opens in quick/engineer modes.
- Reuse the card-3 loader pattern: small dedicated loader class, `drawable-nodpi` assets, blank `ImageView` when unmapped.
- Keep existing card 2 text mapping, cards 1 and 3, confirm button, and session-skip behavior unchanged.

**Non-Goals:**

- Per-device ROM configuration for nozzle images (process model alone drives selection).
- Replacing or migrating `ReminderExactDialog` to `FrostedGlassDialog`.
- Removing legacy `open_laser_icon2` mipmaps (may be deleted in a follow-up if unused elsewhere).
- Changing when the reminder is shown (`ReminderExactBuilder`).

## Decisions

### 1. Asset location: `res/drawable-nodpi/`

**Choice:** Copy the four PNGs into `app/src/main/res/drawable-nodpi/` with underscore resource stems (`nozzle_weld`, `nozzle_cut`, `nozzle_weld_path_clean`, `nozzle_ultra_wide_clean`).

**Rationale:** Matches `fsr_*.png` for card 3; nodpi avoids density scaling artifacts on the fixed 220dp illustration area.

**Alternatives considered:**

- **Keep `@mipmap` with density variants** — rejected; single nodpi PNG is sufficient and matches card 3.
- **Runtime `getIdentifier` lookup by filename** — rejected; explicit `switch` on `ModelConstant` is clearer and compile-time safe (same as `FocusScaleRefImageLoader.drawableIdFor`).

### 2. Loader class: `NozzleReminderImageLoader`

**Choice:** Add `com.lasercyber.lws.ui.common.config.NozzleReminderImageLoader` with:

- `bind(ImageView imageView, int processModel)` — public entry used by `ReminderExactDialog`
- `drawableIdFor(int processModel)` — package-visible or static mapping mirroring `LaserEnableReminderCopy` groupings

Mapping:

```java
switch (processModel) {
    case ModelConstant.HAND_CUT, ModelConstant.CNC_CUT -> R.drawable.nozzle_cut;
    case ModelConstant.WELD_CLEAN -> R.drawable.nozzle_weld_path_clean;
    case ModelConstant.WIDTH_CLEAN -> R.drawable.nozzle_ultra_wide_clean;
    default -> R.drawable.nozzle_weld; // CONTINUOUS_WELDING, POINT_WELDING, unknown
}
```

**Rationale:** Parallels `FocusScaleRefImageLoader`; keeps `LaserEnableReminderCopy` focused on strings only.

### 3. Dialog wiring: extend `bindNozzleTipCard`

**Choice:**

- Add `@+id/iv_nozzle_reminder` to card 2 `ImageView` in `dialog_reminder.xml`; remove `android:src`.
- In `bindNozzleTipCard(processModel)`, after setting tip text, call `NozzleReminderImageLoader.bind(illustration, processModel)`.

**Rationale:** Card 2 text and image share the same `processModel` input already passed to `ReminderExactDialog`; one bind method keeps them in sync.

### 4. Decode strategy: match card 3

**Choice:** Use `BitmapFactory.decodeResource` + `setImageBitmap`, or `setImageResource` when resId non-zero; `setImageDrawable(null)` when resId is 0 or decode fails. Log warnings on missing/failed decode (same log tag as `FocusScaleRefImageLoader`).

**Rationale:** Consistent behavior and observability with existing third-card loader.

## Risks / Trade-offs

- **[Risk] Unknown `processModel` values** → Mitigation: `default` branch uses weld illustration (same as text default); log warning if value is outside known `ModelConstant` range.
- **[Risk] Assets not copied into repo** → Mitigation: tasks include explicit copy step from `Desktop/LwsUI/`; build fails at runtime with blank image if missing, not crash.
- **[Trade-off] Weld and cut each use one image for two sub-modes** → Acceptable; matches existing text grouping and user request.

## Migration Plan

1. Land assets + loader + layout/dialog changes in one PR.
2. No ROM or database migration; behavior changes only when reminder dialog opens.
3. Rollback: revert loader call and restore static `@mipmap/open_laser_icon2` in XML.

## Open Questions

- Should `open_laser_icon2` mipmaps be removed in this change or a cleanup follow-up? (Default: leave in place unless grep confirms no other references.)
