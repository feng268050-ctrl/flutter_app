## Why

In Quick Mode, Weld Path Clean and Ultra-wide Clean use **scan width** (`swingWidth`, 0–6 mm) as the primary process dimension, not material thickness. The right-side wheel next to the circular gauge still shows the **Thickness** label and thickness-based values, which confuses operators and does not reflect the parameter they are selecting.

## What Changes

- When Quick Mode is on **Weld Path Clean** (`ModelConstant.WELD_CLEAN`) or **Ultra-wide Clean** (`ModelConstant.WIDTH_CLEAN`), the right-side picker beside the circular gauge SHALL display the label **Scan Width** (string `swing_width_text`; English: "Scan Width").
- The right-side wheel SHALL list and select process presets by **`swingWidth`** (with mm/in unit display consistent with other Quick Mode pickers), not by `thickness`.
- Process lookup and Modbus send when the wheel changes SHALL match on material + gear + **scan width** for these two modes.
- Welding, point welding, and hand-cut modes SHALL keep the existing **Thickness** label and thickness-based behavior unchanged.

## Capabilities

### New Capabilities

- `quick-mode-clean-scan-width-display`: Quick Mode dashboard right picker shows Scan Width and drives `swingWidth` selection for Weld Path Clean and Ultra-wide Clean.

### Modified Capabilities

- (none)

## Impact

- `fragment_general_operations.xml`, `thickness_pick_v2.xml` — conditional label by `modeType`
- `ThicknessPickV2.java`, `GeneralOperationsFragment.java` — scan-width dimension for clean modes; `initGearAndThickness`, `findNowProcessParametersData`, picker callbacks
- String resources: reuse `@string/swing_width_text` (already "Scan Width" in `values-en`)
- No API or database schema changes; uses existing `ProcessParametersData.swingWidth`
