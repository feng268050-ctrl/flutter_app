# frostui-home-clock Specification

## Purpose
TBD - created by archiving change frostui-home-clock. Update Purpose after archive.
## Requirements
### Requirement: FrostHomeClock renders glyph-masked backdrop blur

`FrostHomeClockView` SHALL replace `FrostedGlassTextView` on the home screen. The control MUST capture the region behind the clock from a sibling `BlurTarget` content child, blur the snapshot through `FrostBackdropBlurRegistry` (RenderScript `BlurUtils.blurBitmap` injected in `FrostUiDialogBridge`), and draw the blurred bitmap only inside filled glyph paths with frost overlay and edge highlight tokens. When no `BlurTarget` is available, the control MUST fall back to the existing gradient glyph fill.

#### Scenario: Clock displays with blur target present

- **WHEN** `FrostHomeClockView` is attached on the home screen with a resolvable local `BlurTarget`
- **THEN** the clock digits show backdrop blur clipped to glyph shapes
- **AND** frost overlay and edge highlights match legacy light-tone appearance

#### Scenario: Clock displays without blur target

- **WHEN** no local `BlurTarget` can be resolved
- **THEN** the clock renders the gradient fallback glyphs without crashing

### Requirement: Home clock refreshes on minute change only

The home clock MUST NOT use a periodic per-second `invalidate` or backdrop refresh timer. Backdrop capture, blur, and redraw MUST occur only when the displayed `HH:mm` minute key changes, or on lifecycle/layout events that require a new snapshot (`onAttachedToWindow`, `onSizeChanged`). Within the same minute, the control MUST reuse the cached blurred backdrop and MUST NOT call `invalidate` for time ticks alone.

#### Scenario: Same minute ticks are ignored

- **WHEN** `updateTime` is called multiple times within the same `HH:mm` minute
- **THEN** the control does not recapture or reblur the backdrop
- **AND** the control does not invalidate solely for those calls

#### Scenario: Minute boundary triggers refresh

- **WHEN** `updateTime` is called and the formatted `HH:mm` differs from the last rendered minute
- **THEN** the control updates glyph paths for the new text
- **AND** captures and blurs a new backdrop snapshot
- **AND** invalidates once after the blur result is ready

#### Scenario: Time correction updates immediately

- **WHEN** NTP sync or manual time set causes `HH:mm` to change outside the `:00` second
- **THEN** the clock updates text and backdrop on that event
- **AND** does not wait for the next minute boundary second

### Requirement: MainActivity updates home clock on minute change only (方案 B)

`MainActivity` SHALL register a `TimeGlobalManager.TimeUpdateListener` that compares the current `HH:mm` string to the last value sent to the home clock. The listener MUST call the home clock API only when `HH:mm` changes. The listener MUST NOT invoke `setText` on every one-second tick.

#### Scenario: Listener skips redundant second ticks

- **WHEN** `TimeGlobalManager` fires `onTimeUpdated` and `HH:mm` is unchanged from the previous callback
- **THEN** `MainActivity` does not call the home clock update API

#### Scenario: Listener forwards minute changes

- **WHEN** `TimeGlobalManager` fires `onTimeUpdated` and `HH:mm` differs from the previous callback
- **THEN** `MainActivity` calls `FrostHomeClockView.updateTime(currentTime)` (or equivalent)

### Requirement: Frost bitmap blur uses RenderScript registry

`FrostBitmapBlur` in `frostui.blur` MUST delegate backdrop bitmap blurring to `FrostBackdropBlurRegistry` (app-injected RenderScript `BlurUtils.blurBitmap`). `FrostHomeClockView` MUST use this path for glyph-clipped backdrop snapshots. The `frostui` package MUST NOT depend on HokoBlur or `com.lasercyber.lws.ui.BlurUtils` directly.

#### Scenario: Clock and dialog fallback share RenderScript backend

- **WHEN** `FrostHomeClockView` or a frost dialog fallback snapshot requests backdrop blur through `FrostBackdropBlurRegistry`
- **THEN** RenderScript Gaussian blur via the registered app implementation is used
- **AND** HokoBlur MUST NOT be invoked

#### Scenario: Clock refresh does not use CPU stack blur

- **WHEN** the home clock updates its blurred glyph backdrop on minute boundaries
- **THEN** blur computation MUST go through `FrostBackdropBlurRegistry`
- **AND** MUST NOT use CPU stack blur

### Requirement: Legacy FrostedGlassTextView is removed after migration

After home layout and `MainActivity` bind to `FrostHomeClockView`, `FrostedGlassTextView.java` MUST be deleted and grep for production references MUST return zero matches.

#### Scenario: No legacy clock view remains

- **WHEN** migration is complete
- **THEN** `activity_main.xml` references `FrostHomeClockView` for `home_real_time`
- **AND** `FrostedGlassTextView` is not referenced in production code

