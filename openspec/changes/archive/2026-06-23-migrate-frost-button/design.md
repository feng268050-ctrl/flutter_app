## Context

`FrostButton` / `FrostButtonView` were introduced in the frostui Compose framework (`frostui-compose-framework`) as the canonical glass action control, but `FrostedGlassButton` remained the class used in every layout XML. The legacy View duplicated border/fill logic and lacked the press alpha + ripple behavior that IME keys already needed from a shared module.

This change completes parity, migrates all call sites, and deletes `FrostedGlassButton.java`.

## Goals / Non-Goals

**Goals:**

- Add `FrostButtonPressFeedback` in `frostui.button` (alpha 225→255, variant ripple, ripple clip aligned to panel fill inset).
- Extend `FrostButton` / `FrostButtonView` for `LIGHT` variant, shape/size, icons, text overrides, and XML attrs via `FrostButtonAttrs`.
- Replace every `FrostedGlassButton` layout reference with `FrostButtonView`; update Java/Kotlin imports and `findViewById` types.
- Move home tile ripple helper to `FrostButtonTileRipple.createTileRippleForeground(cornerRadiusPx)`.
- Point IME key caps (`ImeKeyCap`, `ImeEnterKey`, `ImeShiftKeyCap`) at shared press feedback.
- Update `openspec/specs/frosted-glass-components` and `docs/frostui-compose-refactor-design.md`.

**Non-Goals:**

- Change dialog slot layout or blur/backdrop behavior.
- Migrate non-button glass tiles (`FrostQuickActionEntry`, `FrostRippleClickEntry`) beyond ripple helper extraction.
- Rename XML styleable attrs (`frostedGlassButtonVariant`, etc.) — kept for layout compatibility.

## Decisions

### 1. Compose as single visual source; `FrostButtonView` as XML bridge

`FrostButtonView` extends `AbstractComposeView` and embeds `FrostButton`, matching `FrostCardView` / `FrostSwitchView` interop. XML `LayoutParams` and `android:minWidth` drive shell measurement; Compose fills non-`wrap_content` axes.

Alternative considered: keep `FrostedGlassButton` as a thin Canvas/View wrapper. Rejected — duplicates `frostui.border` painters and diverges from IME Compose keys.

### 2. Shared press feedback module

`FrostButtonPressFeedback.kt` centralizes:

| Token | Value |
|-------|-------|
| Resting alpha (default/secondary) | 225/255 |
| Pressed alpha | 1.0 |
| Disabled alpha | 110/255 |
| Press in / release | 70ms / 140ms |
| Ripple color | white or black per variant |

`frostButtonRippleClipShape` insets by half stroke width so ripple matches `PanelFillPainter` geometry.

IME compose keys import the same modifiers instead of duplicating alpha curves.

### 3. `FrostButtonTileRipple` for non-button glass tiles

Home quick-action and ripple-click entries use `FrostCardView` chrome plus a foreground `RippleDrawable` only. Extract `FrostButtonTileRipple.createTileRippleForeground(cornerRadiusPx)` from the old `FrostedGlassButton.createTileRippleForeground` API so tile ripples stay consistent without pretending tiles are buttons.

### 4. Destructive migration

All layouts grep-clean for `FrostedGlassButton`; class deleted. Styleable renamed to `FrostButton` in `frostui_attrs.xml` while preserving legacy attr names (`frostedGlassButtonVariant`, `frostedGlassButtonSize`, …) so existing XML needs no mass attr rename.

### 5. `LIGHT` variant

`FrostButtonVariant.LIGHT` uses full-opacity glass styling with black ripple for light-on-dark surfaces (e.g. boot self-check, light overlay dialogs). Resting alpha stays at 1.0 like `PRIMARY`.

## Migration Plan

```
Phase 1  FrostButtonPressFeedback + FrostButton extensions (LIGHT, icons, padding overrides)
Phase 2  FrostButtonAttrs + FrostButtonView + FrostButtonTileRipple
Phase 3  Replace FrostedGlassButton in all layout XML (~18 files)
Phase 4  Update Java/Kotlin call sites (dialogs, engineer reminder, home entries, holders)
Phase 5  Delete FrostedGlassButton.java; wire IME to frostui press feedback; update specs/docs
```

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Visual drift vs legacy View | Press tokens copied from `FrostedGlassButton`; manual emulator pass on dialog actions and home tiles |
| XML attr rename breaks layouts | Keep `frostedGlassButton*` attr names on `FrostButton` styleable |
| `AbstractComposeView` measure quirks | `FrostButtonMeasure` + shell `minWidth`/`LayoutParams` contract documented on `FrostButtonView` |

## Verification

- `./gradlew :app:assembleDebug` succeeds with zero `FrostedGlassButton` references.
- `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync` — spot-check frosted dialog confirm/cancel, engineer laser reminder, home quick-action ripple.
