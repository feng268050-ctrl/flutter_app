## Why

The Important Reminder dialog already shows mode-specific **text** on card 2 (weld / cut / clean), but every mode still shares the same static `open_laser_icon2` illustration. Operators need a visual that matches the active process model—especially for clean modes where the nozzle must be removed, not installed.

## What Changes

- Add four nozzle illustration assets (from `Desktop/LwsUI/nozzle-*.png`) under `res/drawable-nodpi/` with Android-safe resource names.
- Introduce a `NozzleReminderImageLoader` (mirroring `FocusScaleRefImageLoader`) that binds card 2's `ImageView` from the active `ModelConstant` at dialog open time.
- Map process models to illustrations:
  - `CONTINUOUS_WELDING`, `POINT_WELDING` → weld nozzle illustration (shared)
  - `HAND_CUT`, `CNC_CUT` → cutting nozzle illustration
  - `WELD_CLEAN` → weld-path clean illustration
  - `WIDTH_CLEAN` → ultra-wide clean illustration
- Remove the hard-coded `@mipmap/open_laser_icon2` from `dialog_reminder.xml`; give card 2 an `ImageView` id for runtime binding.
- When no matching drawable exists, leave the illustration area blank (no crash, no placeholder).

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `laser-enable-reminder-dialog`: Card 2 illustration SHALL be mode-specific (four images, two weld modes share one); update requirement that currently says card 2 icon remains unchanged.

## Impact

- `app/src/main/res/layout/dialog_reminder.xml` — card 2 `ImageView` id, remove static mipmap src
- `app/src/main/res/drawable-nodpi/` — four new `nozzle_*.png` assets
- `ReminderExactDialog.java` — bind nozzle illustration alongside existing `bindNozzleTipCard`
- New `NozzleReminderImageLoader.java` (or extend `LaserEnableReminderCopy` with drawable mapping)
- `openspec/specs/laser-enable-reminder-dialog/spec.md` — requirement delta for card 2 image behavior
- `open_laser_icon2` mipmap may become unused (optional cleanup, not required for behavior)
