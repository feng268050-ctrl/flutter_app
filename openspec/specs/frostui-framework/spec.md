# frostui-framework Specification

## Purpose
TBD - created by archiving change frostui-compose-framework. Update Purpose after archive.
## Requirements
### Requirement: frostui framework layer lives inside app module

The system SHALL provide a logically independent framework package at `com.lasercyber.lws.frostui` under `app/src/main/kotlin/`. The framework MUST NOT be delivered as a separate Gradle library module in this change. Source MUST be organized into top-level subpackages including `border`, `card`, `button`, `control`, and `dialog`, with dependency direction where UI shells (`dialog`) compose containers (`card`, `button`) that draw via `border`.

#### Scenario: frostui does not depend on ui or ai packages

- **WHEN** frostui framework sources are compiled
- **THEN** no frostui source file MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui business code MAY import `com.lasercyber.lws.frostui`

#### Scenario: Layered package structure is enforced

- **WHEN** new frostui framework types are added
- **THEN** border drawing and design tokens MUST reside under `frostui.border`
- **AND** card container and backdrop blur types MUST reside under `frostui.card`
- **AND** button action controls MUST reside under `frostui.button`
- **AND** dialog overlay and prompt shell types MUST reside under `frostui.dialog`
- **AND** clock types MUST reside under `frostui.clock`
- **AND** switch, checkbox, linear slider, segmented control, and capsule slider primitives MUST reside under `frostui.control`

#### Scenario: Control primitives live under frostui.control

- **WHEN** a layout references `com.lasercyber.lws.frostui.control.interop.FrostSwitchView`, `FrostSegmentedControlView`, or `FrostCapsuleSliderView`
- **THEN** the implementation resides under `app/src/main/kotlin/com/lasercyber/lws/frostui/control/`
- **AND** no `frostui` source file imports `com.lasercyber.lws.ui`

### Requirement: frostui uses Jetpack Compose in app module

The `:app` module SHALL enable Jetpack Compose build features and dependencies required for frostui Composables. Kotlin sources for frostui MUST live under `app/src/main/kotlin/com/lasercyber/lws/frostui/`.

#### Scenario: App module compiles frostui Composables

- **WHEN** the project builds `:app:assembleDebug`
- **THEN** frostui `@Composable` functions MUST compile successfully
- **AND** Compose compiler version MUST match the project's Kotlin version

### Requirement: Design tokens are split into dedicated resource files

Frosted-glass design tokens currently scattered in shared `values` files SHALL be consolidated into dedicated resource files under `app/src/main/res/values/` (for example `frostui_colors.xml`, `frostui_dimens.xml`). frostui framework code MUST reference the split token resources as the canonical source during and after migration.

#### Scenario: frostui reads split token resources

- **WHEN** frostui border or card components resolve colors and dimensions
- **THEN** they MUST use tokens from the dedicated `frostui_*` resource files
- **AND** duplicated conflicting token definitions MUST NOT exist for the same visual property after migration completes

### Requirement: Click sound is injected from app layer only

The frostui framework SHALL define `FrostUiClickSound` and `FrostUiClickSoundRegistry` under `frostui.card`. The registry MUST accept a single app-provided implementation at startup. frostui interactive components MUST invoke click sound only through the registry. The framework MUST NOT instantiate `GlobalSoundManager`, `SoundPool`, or load click audio resources directly.

#### Scenario: Application registers click sound at startup

- **WHEN** `LaserApplication` completes initialization
- **THEN** it MUST register a `FrostUiClickSound` that delegates to `GlobalSoundManager.playClickSound`
- **AND** registration MUST occur after `GlobalSoundManager.ensureInitialized`

#### Scenario: Frost button plays injected click sound

- **WHEN** a user activates a frostui `FrostButton` (or equivalent clickable frostui control configured for click sound)
- **THEN** the control MUST call `FrostUiClickSoundRegistry` internal play API
- **AND** the registered app implementation MUST run without frostui referencing `GlobalSoundManager` directly

#### Scenario: Unregistered click sound is silent

- **WHEN** frostui click sound is triggered before registry registration (for example Compose Preview or isolated tests)
- **THEN** the framework MUST NOT throw
- **AND** no click audio MUST play

### Requirement: border package owns glass fill and border painting

The `frostui.border` package SHALL provide the canonical implementation for frosted-glass panel fill and border rendering previously embodied in `FrostedGlassPanelDrawable`, including support for `borderGradientCenter` orientations and button localized-border behavior consumed by card components.

#### Scenario: Border orientations match existing design system

- **WHEN** a frostui consumer selects `borderGradientCenter` of `top-left-bottom-right`, `bottom-left-top-right`, `top-bottom`, or `left-right`
- **THEN** border highlights MUST match the visual contract defined in `frosted-glass-components`
- **AND** automated drawing regression tests MUST be available under frostui test sources

### Requirement: card package provides composable container primitives

The `frostui.card` package SHALL provide `FrostCard` and `FrostBlur` Composables (or equivalent public APIs) that compose `border` painting and live backdrop blur.

#### Scenario: FrostCard renders blur and glass chrome

- **WHEN** `FrostCard` is shown over visible activity content with blur enabled
- **THEN** the card MUST show live blurred backdrop via BlurView sampling a sibling `BlurTarget` (or `FrostCaptureTarget` extending `BlurTarget`)
- **AND** fill and border MUST use `border` package painters and split design tokens
- **AND** the card MUST NOT use CPU stack blur as the primary blur implementation

#### Scenario: Java and XML interop is available

- **WHEN** a legacy Java Fragment or XML layout needs a frostui card
- **THEN** `frostui.card.interop` MUST provide a View wrapper (for example `FrostCardView`) embeddable without rewriting the host screen to Compose

### Requirement: button package provides composable action controls

The `frostui.button` package SHALL provide `FrostButton` and `FrostButtonView` (XML/Java interop). `FrostButton` MUST support `default`, `primary`, `secondary`, and `light` variants and the shape and `borderGradientCenter` options required by `frosted-glass-components`. Press feedback (alpha + ripple) MUST match the legacy glass button contract.

### Requirement: dialog package provides overlay shell for prompts

The `frostui.dialog` package SHALL provide overlay lifecycle management and a prompt dialog shell with title, body, and action slots equivalent to the frostui migration target for `FrostedGlassDialog.prompt()`. Overlay implementation MUST preserve activity-safe attach/detach and scrim/blur/card chrome behavior required by `frosted-glass-dialog`.

#### Scenario: Prompt shell exposes title body and action slots

- **WHEN** frostui prompt dialog is shown with default configuration
- **THEN** title, text body, and confirm/cancel action areas MUST be available
- **AND** custom slot replacement MUST remain supported for migration of feature-specific bodies

### Requirement: Legacy FrostedGlass View implementations are removed when unreferenced

After call sites migrate to frostui, unused `FrostedGlass*` View implementation classes under `ui.component.dialog` SHALL be deleted. Migration MUST NOT remove layouts still required by active `customBodyView` feature wrappers until those wrappers are migrated or confirmed obsolete.

#### Scenario: No orphaned FrostedGlass View classes remain

- **WHEN** all references to a legacy `FrostedGlass*` View class are removed from the codebase
- **THEN** that class MUST be deleted in the same change series or a follow-up task within this change
- **AND** builds and frostui regression tests MUST pass after deletion

### Requirement: Interactive frostui controls use click sound registry

`frostui.control` interactive components (`FrostSwitch`, `FrostCheckbox`, `FrostSegmentedControl`, `FrostCapsuleSlider` on start tracking, and `FrostSlider` / `FrostSliderView` on long-press arm and release when `longPressDragEnabled` is true) MUST invoke click sound only through `FrostUiClickSoundRegistry`, consistent with `FrostButton`.

#### Scenario: Control toggle plays injected click sound

- **WHEN** a user successfully toggles `FrostSwitch` or `FrostCheckbox`
- **THEN** the control MUST call the frostui click-sound registry
- **AND** frostui control code MUST NOT reference `GlobalSoundManager` directly

### Requirement: FrostSlider long-press arm and drag release use click sound registry

When a `FrostSlider` or `FrostSliderView` with `longPressDragEnabled=true` completes long-press arming or ends an armed drag session, the control MUST invoke `FrostUiClickSoundRegistry` for audible feedback. Short taps on the thumb that do not reach the long-press threshold MUST NOT play click sound. Track taps outside the thumb MUST NOT play click sound.

#### Scenario: Arm sound on long-press threshold

- **WHEN** the user holds the slider thumb until the long-press threshold elapses and drag becomes armed
- **THEN** the slider MUST call `FrostUiClickSoundRegistry` exactly once for the arm event
- **AND** frostui MUST NOT reference `GlobalSoundManager` directly

#### Scenario: Release sound after armed drag

- **WHEN** the user releases the pointer after dragging while `isValueArmed` was true
- **THEN** the slider MUST call `FrostUiClickSoundRegistry` exactly once for the release event

#### Scenario: Short thumb tap is silent

- **WHEN** the user releases the thumb before the long-press threshold without arming drag
- **THEN** no click sound MUST play

### Requirement: Frost backdrop blur uses RenderScript via registry injection

The `frostui.blur` package SHALL provide `FrostBitmapBlur` as a thin facade over `FrostBackdropBlurRegistry`. `FrostBackdropBlurRegistry` MUST receive its implementation from the app layer (`FrostUiDialogBridge`) using RenderScript Gaussian blur via `BlurUtils.blurBitmap`. frostui MUST NOT import `com.lasercyber.lws.ui.common.utils.BlurUtils`. frostui MUST NOT use CPU stack blur or HokoBlur for frost backdrop blur.

#### Scenario: Registry blur uses RenderScript after bridge init

- **WHEN** `FrostUiDialogBridge` initializes frostui registries
- **THEN** `FrostBackdropBlurRegistry` MUST be registered with a `BlurUtils.blurBitmap`-backed implementation
- **AND** frost dialog snapshot fallback blur MUST use the same registry backend

#### Scenario: Live card blur uses BlurView not offline CPU blur

- **WHEN** `FrostCardView` enables backdrop blur and a valid sibling `BlurTarget` is available
- **THEN** the card MUST attach and configure a live `BlurView` via shared `frostui.blur.FrostBlurViewSupport`
- **AND** MUST NOT run CPU stack blur on the main blur path

#### Scenario: BlurView failure falls back to RenderScript snapshot

- **WHEN** live `BlurView` setup fails (for example different windows or no hardware acceleration)
- **THEN** the card MAY capture a downscaled snapshot and blur it through `FrostBackdropBlurRegistry` (RenderScript)
- **AND** MUST NOT fall back to CPU stack blur

### Requirement: FrostSegmentedControl long-press arm and drag release use click sound registry

When `FrostSegmentedControl` or `FrostSegmentedControlView` has `clickSoundEnabled=true`, long-press arming on the selected segment and release after an armed drag session MUST invoke `FrostUiClickSoundRegistry`. Tap selection on an unselected segment MUST continue to play a single click sound. Short press on the selected segment without arming MUST NOT play sound.

#### Scenario: Arm sound on segment long-press threshold

- **WHEN** the user holds the selected segment until the long-press threshold elapses and the pill expands
- **THEN** the control MUST call `FrostUiClickSoundRegistry` exactly once for the arm event
- **AND** frostui MUST NOT reference `GlobalSoundManager` directly

#### Scenario: Release sound after armed segment drag

- **WHEN** the user releases the pointer after dragging while selection was armed
- **THEN** the control MUST call `FrostUiClickSoundRegistry` exactly once for the release event

#### Scenario: Segment row with click sound disabled

- **WHEN** `frostClickSoundEnabled` is false on the view (for example sound-effect preset row)
- **THEN** neither tap nor long-press arm/release MUST play click sound

