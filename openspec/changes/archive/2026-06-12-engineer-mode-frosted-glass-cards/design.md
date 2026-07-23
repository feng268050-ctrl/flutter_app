## Context

Engineer Mode parameter screens (`EngineerWeldingFragment`, `EngineerCuttingFragment`, `EngineerWashFragment`) render card chrome via `@mipmap` nine-patch-style backgrounds and action buttons via `@mipmap/welding_reset_box` and `@mipmap/welding_mark_box`. Selection popups originally used `PopupWindow` + `@mipmap/material_popup_bg`; the final implementation uses **`FrostedGlassPopupMenu`** (in-window overlay + `FrostedGlassCard` list chrome).

Settings (`fragment_common_settings.xml`, `fragment_advanced_setting.xml`) and Monitor already consume `FrostedGlassCard` / `FrostedGlassButton` with `app:cardBackground="transparent"` and configurable `app:borderGradientCenter`. The shared component API and tokens are defined in `frosted-glass-components` spec; no new component work is required.

Welding layout is split: left `chartContent` (508dp, chart) and right form panel. Cutting and Cleaning use a single full-width form card.

## Goals / Non-Goals

**Goals:**

- Replace scoped image-backed cards and buttons with FrostedGlass equivalents, matching Monitor/Settings visual language.
- Apply per-surface `borderGradientCenter` as specified: welding left `top-left-bottom-right`, welding right `bottom-left-top-right` (API name for top-right/bottom-left highlight pair), single-card tabs `top-left-bottom-right`, action buttons `top-left-bottom-right`.
- Use transparent card background (`app:cardBackground="transparent"`) on all migrated cards.
- Migrate More Common Specs and Material Type popups to shared `FrostedGlassPopupMenu` with Settings-style `InsetList` rows.
- Use fade-only overlay animation; right-align menu to anchor; uniform per-row selection corners; scrollbar when scrolling.
- Fix English More Common Specs label to Title Case.
- Fix Custom material → text dialog crash when popup blur session restores while dialog overlay is open.
- Save as Common: upsert by `processType` + `name`; suggest default name from material/thickness display labels.

**Non-Goals:**

- Engineer tab bar / orange pill buttons in `activity_engineer_mode.xml`.
- Chart components (`ContinuousWeldingLineChart`, `SpotWeldingLineChart`), parameter rows, scroll behavior, or ViewModel/session logic.
- Numeric/text FrostedGlass dialogs (already migrated).
- Changing popup list item data sources, selection callbacks, or Material Type anchor Y placement (horizontal right-align is in scope).
- Broader string localization beyond `more_common_specs` English Title Case.
- Dead-asset deletion repo-wide unless the replaced mipmaps have zero remaining references after this change.

## Decisions

### 1. Wrap existing layout trees in FrostedGlassCard rather than restructuring content

Replace the `android:background="@mipmap/..."` on container `LinearLayout`s with outer `FrostedGlassCard` wrappers (or swap the container element type), preserving inner padding, margins, and child IDs. This minimizes binding/fragment Java churn.

**Alternative considered:** Flatten and re-padding from scratch — rejected as higher risk with no visual benefit.

### 2. Map user-facing gradient names to existing enum values

| Surface | User term | XML `borderGradientCenter` |
|---------|-----------|----------------------------|
| Welding left chart card | top-left-bottom-right | `top-left-bottom-right` |
| Welding right form card | top-right-bottom-left | `bottom-left-top-right` |
| Cutting / Cleaning card | top-left-bottom-right | `top-left-bottom-right` |
| Reset / Save buttons | top-left-bottom-right | `top-left-bottom-right` |
| Popup container | (unspecified; use default diagonal) | `top-left-bottom-right` |

No new enum values; `bottom-left-top-right` already implements the top-right / bottom-left highlight pair used elsewhere (e.g. Monitor `StatAdapter` column 0).

### 3. FrostedGlassButton for Reset / Save with `default` variant

Existing buttons are neutral glass capsules with white text and start drawables — not primary orange CTAs. Use `FrostedGlassButton` with `app:frostedGlassButtonVariant="default"` (or omit variant), `app:frostedGlassButtonShape="rounded"`, and preserve existing padding, drawables, and `android:onClick` bindings. Replace `<Button>` with `<FrostedGlassButton>`; drop `@mipmap` backgrounds from styles.

**Alternative considered:** `primary` variant — rejected; would change emphasis to orange fill inconsistent with current design.

### 4. `FrostedGlassPopupMenu` in-window overlay (replaces `PopupWindow`)

Engineer selection popups attach a full-screen `FrameLayout` to `Activity` `android.R.id.content`, fade alpha in/out (~300ms), and host a `FrostedGlassCard` list. `DataListPopup` remains the engineer-facing API and delegates to `FrostedGlassPopupMenu`.

**Positioning:** menu width is fixed (350dp); `left = anchorRight - width` (clamped to screen) so the panel grows leftward from the anchor's trailing edge.

**Rows:** programmatic `InsetList` + inflated `frosted_glass_popup_menu_item.xml` (`InsetListRow`); selection via `ListSelectionBackgroundUtils.applyUniform()` (8dp on all corners). `RecyclerView` position-based corner radii were abandoned because middle rows lost corner highlights.

**Scroll:** `AppScrollView` with global scrollbar thumb; awaken scrollbars on scroll.

### 5. Window blur session vs dialog overlay

`FrostedGlassCard` on the popup acquires a shared window `BlurTarget` via `FrostedGlassBlurSupport`. Opening `FrostedGlassTextInputDialog` (Custom material) while the popup overlay is fading out previously restored the blur wrapper too early → `IllegalStateException` on `addView`.

**Fix:** defer `WindowBlurSession.restore()` while `FrostedGlassOverlayHost.hasOverlays()`; call `FrostedGlassBlurSupport.tryRestorePending()` when the last dialog overlay is removed.

### 6. Save as Common upsert and default name

- **Upsert key:** `(processType, name)` among engineer rows (`dataType` 1 or legacy 2). Lookup via `selectEngineerByProcessTypeAndNameSync`; update existing row or insert with `id = null`. Does not update "whatever preset is currently selected" unless names match.
- **Default prompt text:** `getSuggestedCommonlyUsedParameterName()` → `{materialTypeLabel}-{thicknessLabel}{unit}` using the same display formatters as the Engineer UI (`mm` / `in`). Weld Path Clean / Ultra-wide Clean: material label only (no thickness field).

### 7. String change limited to English default and values-en

Update `values/strings.xml` and `values-en/strings.xml` `more_common_specs` to `More Common Specs`. Leave `values-zh/strings.xml` unchanged (`更多常用工艺`).

## Risks / Trade-offs

- **[Risk] FrostedGlassCard blur on Engineer Mode may differ from static mipmap appearance** → Mitigation: use `cardBackground="transparent"` and match existing dimensions; verify on emulator across all four tabs.
- **[Risk] FrostedGlassButton capsule width may differ from mipmap button** → Mitigation: copy explicit padding from current styles; adjust min width only if visual QA shows clipping.
- **[Risk] Fade-only popup may feel less directional than slide** → Mitigation: scoped to two popups per user request; duration matches existing 300ms.
- **[Risk] Binding references to `<Button>` types** → Mitigation: grep fragments for `Button` casts on reset/save IDs; update only if present.

## Migration Plan

1. Update welding/cutting/wash fragment layouts (cards + buttons).
2. Implement `FrostedGlassPopupMenu` + engineer `DataListPopup` wrapper; verify popups, Custom dialog, scrollbar, selection.
3. Update Save as Common upsert + default name; update English strings.
4. Build and `make sync`; manually verify all four tabs — cards, buttons, popups, Save as Common insert/update, Custom material dialog.
5. Remove unused `@mipmap` references if zero usages remain (optional cleanup in same PR).

Rollback: revert layout/XML/anim/string changes; no data migration.

## Open Questions

None — scope and gradient mapping are explicit in the user request.
