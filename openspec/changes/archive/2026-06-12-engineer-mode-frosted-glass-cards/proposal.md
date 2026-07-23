## Why

Engineer Mode still uses legacy `@mipmap` image backgrounds for parameter cards, action buttons, and selection popups (`engineer_chart_background`, `engineer_chart_right_content`, `engineer_mode_big_background`, `welding_reset_box`, `welding_mark_box`, `material_popup_bg`). Settings and Monitor have already migrated to shared `FrostedGlassCard` / `FrostedGlassButton`, so Engineer Mode looks visually inconsistent and carries extra bitmap assets. Migrating the scoped surfaces to FrostedGlass aligns HMI chrome and reuses the established glass border gradient system.

## What Changes

- Replace image-resource-backed card containers in Engineer Mode with `FrostedGlassCard` using `cardBackground="transparent"`:
  - **Continuous Weld / Spot Weld** (`fragment_engineer_welding.xml`): left chart panel and right form panel — left card uses `borderGradientCenter="top-left-bottom-right"`, right card uses `borderGradientCenter="bottom-left-top-right"` (top-right / bottom-left highlight pair).
  - **Cutting / Cleaning** (`fragment_engineer_cutting.xml`, `fragment_engineer_wash.xml`): single form card with `borderGradientCenter="top-left-bottom-right"`.
- Replace **Reset to Default** and **Save as Common** image-backed buttons with `FrostedGlassButton` (`borderGradientCenter="top-left-bottom-right"`), preserving labels, icons, enabled/disabled behavior, and click handlers.
- Replace **More Common Specs** and **Material Type** popup chrome with shared **`FrostedGlassPopupMenu`** (`FrostedGlassCard` + `InsetList` rows, in-window overlay on `android.R.id.content` for backdrop blur) instead of legacy `PopupWindow` + `@mipmap/material_popup_bg`.
- Popup UX polish: **right-align** menu to anchor (avoid horizontal overflow), **uniform rounded selection** on all four corners per row, **vertical scrollbar** when list scrolls, Material Type leading icon symmetric with trailing chevron.
- Rename English string **More common specs** → **More Common Specs** (Title Case).
- Change More Common Specs and Material Type popup show/dismiss to **fade-only** (alpha in/out) on the in-window overlay.
- Fix **Material Type → Custom** opening the material name dialog while the popup is dismissing (coordinate `FrostedGlassBlurSupport` window-blur restore with `FrostedGlassOverlayHost` dialog overlays).
- **Save as Common** semantics: upsert engineer preset by **`processType` + `name`** (insert when name is new for that process type, update when it already exists); default name in the prompt is **`{Material Type display}-{thickness display}{unit}`** (cleaning tabs: material display only).
- **Out of scope:** engineer tab bar buttons, chart rendering, parameter row validation rules, numeric/text input dialog chrome (already FrostedGlass), orange tab pills in `activity_engineer_mode.xml`, and any other Engineer Mode surfaces not listed above.

## Capabilities

### New Capabilities

- `engineer-mode-glass-cards`: Engineer Mode card, button, and selection-popup chrome SHALL use `FrostedGlassCard` / `FrostedGlassButton` with documented per-surface `borderGradientCenter` and transparent card background conventions.

### Modified Capabilities

- `engineer-mode-common-params`: Add requirements for FrostedGlass popup chrome, fade-only popup animation, English Title Case label for More Common Specs, Save as Common upsert-by-name, and suggested default preset names. Session baseline / reset semantics remain unchanged.

## Impact

- Layout XML: `fragment_engineer_welding.xml`, `fragment_engineer_cutting.xml`, `fragment_engineer_wash.xml`, `frosted_glass_popup_menu.xml`, `frosted_glass_popup_menu_item.xml`.
- Styles / dimens: popup menu card padding, row spacing, selection corner radius; optional `InsetListRow` attrs (`horizontalInset`, `rowVerticalPadding`, `rowMinHeight`).
- Java: `FrostedGlassPopupMenu`, `DataListPopup` (wrapper), `DataPopupBuilder`, `FrostedGlassBlurSupport`, `FrostedGlassOverlayHost`, `ProcessParametersDataViewModel.saveCommonlyUsedParameter`, `BaseProcessParametersDataViewModel.getSuggestedCommonlyUsedParameterName`, `InputDialogBuilder.commonlyUsedParameterBuilder`, `ProcessParametersDataDao.selectEngineerByProcessTypeAndNameSync`.
- Strings: `more_common_specs` in `values/strings.xml` and `values-en/strings.xml`.
- Removes in-scope dependencies on `@mipmap/engineer_chart_background`, `engineer_chart_right_content`, `engineer_mode_big_background`, `welding_reset_box`, `welding_mark_box`, and `material_popup_bg` once unreferenced.
- **Database:** Save as Common upsert keyed by `processType` + `name` on `t_process_parameters_data` (`ENGINEER_MODE_DATA` / legacy type 2 rows). No API, Modbus, or WebSocket changes.
