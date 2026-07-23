# Migrate FrostedGlassButton → FrostButton

- [x] 1.1 Add shared `FrostButtonPressFeedback` (alpha 225→255 + variant ripple) in frostui
- [x] 1.2 Extend `FrostButton` with press feedback, shape/size, LIGHT variant, icons, text overrides
- [x] 1.3 Add `FrostButtonAttrs` + full `FrostButtonView` XML/Java interop
- [x] 1.4 Add `FrostButtonTileRipple` replacing `FrostedGlassButton.createTileRippleForeground`

- [x] 2.1 Replace `FrostedGlassButton` in all layout XML with `FrostButtonView`
- [x] 2.2 Update Java/Kotlin references (`findViewById` types, imports, tile ripple)

- [x] 3.1 Delete `FrostedGlassButton.java`; rename styleable to `FrostButton` in attrs
- [x] 3.2 Point IME press feedback at frostui shared module
- [x] 3.3 Update `openspec/specs`, `docs/frostui-compose-refactor-design.md`
