## MODIFIED Requirements

### Requirement: card package provides composable container primitives

The `frostui.card` package SHALL provide `FrostCard` and `FrostBlur` Composables (or equivalent public APIs) that compose `border` painting and live backdrop blur.

#### Scenario: FrostCard renders blur and glass chrome

- **WHEN** `FrostCard` is shown over visible activity content with blur enabled
- **THEN** the card MUST show live blurred backdrop via BlurView sampling a sibling `BlurTarget` (or approved `FrostCaptureTarget` that extends `BlurTarget`)
- **AND** fill and border MUST use `border` package painters and split design tokens
- **AND** the card MUST NOT use CPU stack blur (`FrostStackBlur`) as the primary blur implementation

#### Scenario: Java and XML interop is available

- **WHEN** a legacy Java Fragment or XML layout needs a frostui card
- **THEN** `frostui.card.interop` MUST provide a View wrapper (for example `FrostCardView`) embeddable without rewriting the host screen to Compose

## ADDED Requirements

### Requirement: Frost backdrop blur uses RenderScript via registry injection

The `frostui.blur` package SHALL provide `FrostBitmapBlur` as a thin facade over `FrostBackdropBlurRegistry`. `FrostBackdropBlurRegistry` MUST receive its implementation from the app layer (`FrostUiDialogBridge`) using RenderScript Gaussian blur via `BlurUtils.blurBitmap`. frostui MUST NOT import `com.lasercyber.lws.ui.common.utils.BlurUtils`. frostui MUST NOT use CPU stack blur (`FrostStackBlur`) or HokoBlur for frost backdrop blur.

#### Scenario: Registry blur uses RenderScript after bridge init

- **WHEN** `FrostUiDialogBridge` initializes frostui registries
- **THEN** `FrostBackdropBlurRegistry` MUST be registered with a `BlurUtils.blurBitmap`-backed implementation
- **AND** frost dialog snapshot fallback blur MUST use the same registry backend

#### Scenario: Live card blur uses BlurView not offline CPU blur

- **WHEN** `FrostCardView` enables backdrop blur and a valid sibling `BlurTarget` is available
- **THEN** the card MUST attach and configure a live `BlurView` via shared `frostui.blur` support APIs
- **AND** MUST NOT run `FrostStackBlur` on the main blur path

#### Scenario: BlurView failure falls back to RenderScript snapshot

- **WHEN** live `BlurView` setup fails (for example different windows or no hardware acceleration)
- **THEN** the card MAY capture a downscaled snapshot and blur it through `FrostBackdropBlurRegistry` (RenderScript)
- **AND** MUST NOT fall back to CPU stack blur

## REMOVED Requirements

### Requirement: Frost backdrop blur uses HokoBlur via registry injection

**Reason**: Replaced by live BlurView + RenderScript registry; HokoBlur removed from frost backdrop paths.

**Migration**: Register `BlurUtils.blurBitmap` in `FrostUiDialogBridge`; implement `FrostBlurViewSupport` for cards; delete `FrostStackBlur`.
