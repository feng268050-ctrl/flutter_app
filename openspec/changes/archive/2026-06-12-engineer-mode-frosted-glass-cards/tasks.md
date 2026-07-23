## 1. Welding fragment cards and buttons

- [x] 1.1 In `fragment_engineer_welding.xml`, replace left `chartContent` `@mipmap/engineer_chart_background` with `FrostedGlassCard` (`cardBackground="transparent"`, `borderGradientCenter="top-left-bottom-right"`), preserving 508dp width and chart child.
- [x] 1.2 Replace right form panel `@mipmap/engineer_chart_right_content` with `FrostedGlassCard` (`cardBackground="transparent"`, `borderGradientCenter="bottom-left-top-right"`), preserving margins and inner layout.
- [x] 1.3 Replace Reset to Default and Save as Common `<Button>` elements with `FrostedGlassButton` (`borderGradientCenter="top-left-bottom-right"`, default variant, existing drawables/padding/onClick).

## 2. Cutting and Cleaning fragment cards and buttons

- [x] 2.1 In `fragment_engineer_cutting.xml`, replace `@mipmap/engineer_mode_big_background` form container with `FrostedGlassCard` (`cardBackground="transparent"`, `borderGradientCenter="top-left-bottom-right"`).
- [x] 2.2 In `fragment_engineer_wash.xml`, apply the same single-card FrostedGlass migration as Cutting.
- [x] 2.3 Replace Reset to Default and Save as Common buttons in both cutting and wash layouts with `FrostedGlassButton` matching welding configuration.

## 3. Selection popup chrome and animation

- [x] 3.1 Add fade-only popup overlay animation (~300ms alpha) on in-window `FrostedGlassPopupMenu` host.
- [x] 3.2 Implement `FrostedGlassPopupMenu` + layouts `frosted_glass_popup_menu.xml` / `frosted_glass_popup_menu_item.xml`; refactor `DataListPopup` as thin wrapper.
- [x] 3.3 Right-align popup to anchor; replace `RecyclerView` with `InsetList` rows and uniform selection corners; add `AppScrollView` scrollbar.

## 4. Strings and cleanup

- [x] 4.1 Update `more_common_specs` to `More Common Specs` in `values/strings.xml` and `values-en/strings.xml`.
- [x] 4.2 Remove or stop referencing `@mipmap` backgrounds from `engineer_reset_btn_style` / `engineer_mark_common_btn_style` if layouts no longer use those styles.
- [x] 4.3 Grep for orphaned `@mipmap/engineer_chart_background`, `engineer_chart_right_content`, `engineer_mode_big_background`, `welding_reset_box`, `welding_mark_box`, `material_popup_bg` references; remove only if zero usages remain.

## 5. Verification (initial glass migration)

- [x] 5.1 Build and `make sync`; verify Continuous Weld and Spot Weld dual cards (gradient orientation), Cutting and Cleaning single card, Reset/Save buttons, More Common Specs and Material Type popups (FrostedGlass chrome + fade animation), and unchanged parameter/edit behavior.

## 6. Popup and dialog stability

- [x] 6.1 Extend `InsetListRow` with `horizontalInset`, `rowVerticalPadding`, `rowMinHeight` for engineer popup row density without breaking Settings defaults.
- [x] 6.2 Align Material Type capsule leading icon with trailing chevron on welding/cutting/wash layouts.
- [x] 6.3 Fix Custom → material name dialog crash: defer `FrostedGlassBlurSupport` window-blur restore while `FrostedGlassOverlayHost` has dialog overlays; `tryRestorePending` on last overlay removed.

## 7. Save as Common semantics

- [x] 7.1 Upsert by `processType` + `name` in `saveCommonlyUsedParameter` with `ProcessParametersDataDao.selectEngineerByProcessTypeAndNameSync`.
- [x] 7.2 Pre-fill Save as Common dialog via `getSuggestedCommonlyUsedParameterName()` (`{material display}-{thickness}{unit}`; cleaning tabs material only).

## 8. Final verification

- [x] 8.1 Build and `make sync`; verify popup alignment/selection/scroll, Custom material dialog, Save as Common insert vs update-by-name, and suggested default names on all four Engineer tabs.
