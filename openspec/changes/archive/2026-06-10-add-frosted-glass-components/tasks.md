## 1. Shared FrostedGlass Foundation

- [x] 1.1 Add FrostedGlass component attrs/resources for card fill, border visibility, button variant, and `borderGradientCenter` values.
- [x] 1.2 Extend the shared panel/border drawable implementation so it supports `top-left-bottom-right`, `bottom-left-top-right`, `top-bottom`, and `left-right` highlight centers.
- [x] 1.3 Implement `FrostedGlassCard` as a reusable rounded container with XML and programmatic configuration for fill, border, padding/size defaults, clipping, and `borderGradientCenter`.
- [x] 1.4 Implement `FrostedGlassButton` with primary/secondary variants, shared border/fill primitives, text defaults, minimum touch target, and enabled/pressed/focused/selected state feedback.

## 2. Dialog Integration

- [x] 2.1 Update `dialog_frosted_glass_prompt.xml` or its inflation path so the card chrome is supplied by `FrostedGlassCard`.
- [x] 2.2 Refactor `FrostedGlassOverlayHost` to stop applying ad-hoc `FrostedGlassPanelDrawable` background/foreground directly to dialog content.
- [x] 2.3 Migrate default dialog confirm/cancel controls to shared `FrostedGlassButton` styling while preserving visibility, text, callbacks, and layout spacing.
- [x] 2.4 Check existing FrostedGlass dialog wrappers that use custom bodies and adapt only the shared card/button integration points needed for compatibility.

## 3. Verification

- [x] 3.1 Smoke test a simple `FrostedGlassDialog.prompt(...)` title/message/action dialog for unchanged appearance and dismissal behavior.
- [x] 3.2 Smoke test at least one custom-body dialog and one input dialog wrapper to verify slot lookup, IME handling, and blur behavior still work.
- [x] 3.3 Verify each `borderGradientCenter` value renders the expected highlight orientation on `FrostedGlassCard`.
- [x] 3.4 Run the relevant Android build or UI module compile check and fix any resource/style regressions.

## 4. Button Border Refinement (post-initial rollout)

- [x] 4.1 Add `localizedBorder` support to `FrostedGlassPanelDrawable` and enable it from rounded capsule `FrostedGlassButton` instances.
- [x] 4.2 Implement diagonal localized borders with soft-shadow base plus paired corner radial highlights; tune radius, alpha stops, and `softShadowColor()` blend for capsule buttons.
- [x] 4.3 Implement axis-aligned localized borders with full-edge linear highlights for `top-bottom` and `left-right` on rounded buttons.
- [x] 4.4 Add `default` variant, `rounded`/`rectangle` shape, custom `borderRadius`, and primary/secondary color tokens; make `primary` use flat opaque orange fill.
- [x] 4.5 Add `FrostedGlassPanelDrawableInstrumentedTest` coverage for all four `borderGradientCenter` orientations on the shared drawable.

## 5. Screen and Dialog Adoption

- [x] 5.1 Migrate Safety Operations Tips and Product Use Disclaimer screens to `FrostedGlassCard` plus `FrostedGlassButton` for agree actions; keep Product Use Disclaimer link as text.
- [x] 5.2 Migrate default FrostedGlass prompt cancel/confirm and Startup Self-Check close controls to `FrostedGlassButton`.
- [x] 5.3 Standardize adopted button chrome on `top-left-bottom-right`; set dialog confirm and Safety Tips agree actions to `primary`, cancel/close to `default`.
- [x] 5.4 Verify adopted screens and dialogs on emulator via `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync`.
