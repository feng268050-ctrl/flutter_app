## 1. Layout — mode-aware label

- [x] 1.1 In `thickness_pick_v2.xml`, bind the title `TextView` to `swing_width_text` when `modeType` is `WELD_CLEAN` or `WIDTH_CLEAN`, else `thickness_text` (import `ModelConstant` if needed)

## 2. Fragment — scan width dimension

- [x] 2.1 Add `activeSwingWidth` and `swingWidthKey` helper (null → 0) in `GeneralOperationsFragment`
- [x] 2.2 Add `convertToSwingWidthData` mirroring `convertToThicknessData` formatting for `swingWidth`
- [x] 2.3 Branch `initGearAndThickness`: for clean modes, build right wheel from distinct `swingWidth`; for others, keep thickness map
- [x] 2.4 Branch `findNowProcessParametersData`: clean modes match `swingWidthKey(activeSwingWidth)`; others keep thickness match
- [x] 2.5 Update thickness picker listener log/comment to reflect scan width when in clean mode

## 3. Verification

- [x] 3.1 Manual: Quick Mode → Weld Path Clean — right label "Scan Width", wheel shows swing widths, Modbus send on change
- [x] 3.2 Manual: Quick Mode → Ultra-wide Clean — same as 3.1
- [x] 3.3 Manual: Continuous Welding / Hand Cut — right label still Thickness, behavior unchanged
