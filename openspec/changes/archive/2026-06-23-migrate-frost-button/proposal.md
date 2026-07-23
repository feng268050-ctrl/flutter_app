# Migrate FrostedGlassButton → FrostButton

## Why

`FrostButton` was implemented as the Compose successor to `FrostedGlassButton` but lacked press ripple feedback and remained unused while the legacy View class continued to ship in all layouts. This change completes parity (alpha + ripple), migrates every call site to `FrostButtonView`, and removes the duplicate View implementation.

## What

- Add `FrostButtonPressFeedback` shared with IME keys (alpha 225→255, variant ripple)
- Extend `FrostButton` / `FrostButtonView` for shape, size, icons, LIGHT variant
- Replace all layout XML and Java references; delete `FrostedGlassButton.java`
- Move tile ripple helper to `FrostButtonTileRipple`
- Update frosted-glass component specs and design docs

## Impact

- Affected specs: `frosted-glass-components`, settings/monitor/engineer/quick-mode dialog specs
- Affected code: `frostui.card`, all layouts using glass buttons, home tile ripple entries
