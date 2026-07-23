## ADDED Requirements

### Requirement: Frost bitmap blur uses RenderScript registry

`FrostBitmapBlur` in `frostui.blur` MUST delegate backdrop bitmap blurring to `FrostBackdropBlurRegistry` (app-injected RenderScript `BlurUtils.blurBitmap`). `FrostHomeClockView` MUST use this path for glyph-clipped backdrop snapshots. The `frostui` package MUST NOT depend on HokoBlur or `com.lasercyber.lws.ui.BlurUtils` directly.

#### Scenario: Clock and dialog fallback share RenderScript backend

- **WHEN** `FrostHomeClockView` or a frost dialog fallback snapshot requests backdrop blur through `FrostBackdropBlurRegistry`
- **THEN** RenderScript Gaussian blur via the registered app implementation is used
- **AND** HokoBlur MUST NOT be invoked

#### Scenario: Clock refresh does not use CPU stack blur

- **WHEN** the home clock updates its blurred glyph backdrop on minute boundaries
- **THEN** blur computation MUST go through `FrostBackdropBlurRegistry` or live `BlurView` sampling
- **AND** MUST NOT use `FrostStackBlur`

## REMOVED Requirements

### Requirement: Frost bitmap blur uses HokoBlur

**Reason**: Superseded by RenderScript registry alignment with BlurView live blur strategy.

**Migration**: Rewire `FrostBitmapBlur` to registry; remove `hoko-blur` dependency when unused.
