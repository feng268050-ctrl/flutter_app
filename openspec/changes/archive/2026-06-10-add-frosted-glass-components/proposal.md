## Why

Liquid glass styling is currently embedded in the dialog shell, which makes the glass border, blur-ready card background, and button treatment hard to reuse consistently across the HMI. Extracting shared FrostedGlass components gives new screens a single visual contract and lets existing dialogs keep their current look while moving onto reusable building blocks.

## What Changes

- Add a reusable `FrostedGlassCard` component that provides the shared rounded glass fill, border, and sizing/padding options expected from a UI container.
- Add `borderGradientCenter` support so callers can choose where the border highlight is centered: `top-left-bottom-right`, `bottom-left-top-right`, `top-bottom`, or `left-right`.
- Add a reusable `FrostedGlassButton` component for `default`, `primary`, and `secondary` action controls with the same glass visual language, shape options (`rounded` capsule vs `rectangle`), optional custom `borderRadius`, and button-focused state handling.
- Evolve `FrostedGlassPanelDrawable` with button-specific localized border rendering so rounded capsule buttons avoid sweep/linear gradient artifacts on diagonal highlights while still supporting all four `borderGradientCenter` values.
- Refactor `FrostedGlassDialog` and future FrostedGlass-style dialogs to build their shell/card chrome on `FrostedGlassCard` instead of owning separate panel styling.
- Adopt the shared components on Safety Operations Tips, Product Use Disclaimer, default FrostedGlass prompt actions, and Startup Self-Check close control.
- Preserve the existing `FrostedGlassDialog.prompt(...)` public behavior and slot model while sharing the new component implementation.

## Capabilities

### New Capabilities
- `frosted-glass-components`: Reusable FrostedGlass card and button components, including configurable border gradient center behavior.

### Modified Capabilities
- `frosted-glass-dialog`: Dialog shell requirements change so FrostedGlass dialogs use the shared `FrostedGlassCard` foundation rather than ad-hoc panel drawable setup.

## Impact

- Affected UI code: `com.lasercyber.lws.ui.component.dialog` and any new shared component package selected during implementation.
- Affected resources: FrostedGlass dimensions, colors (including primary-button and secondary-text tokens), drawables, Safety Tips layouts, dialog layouts, and instrumented drawable coverage for border orientation.
- Affected verification: `ADB_SERIAL=emulator-5554 SKIP_BUNDLED_FETCH=1 make sync` for emulator install/launch during UI review.
- Public APIs: new reusable component APIs for card/button styling; existing `FrostedGlassDialog` prompt APIs should remain source-compatible.
- Dependencies: no new third-party dependencies expected; implementation should reuse the current BlurView/dialog infrastructure and existing Android view system.
