## ADDED Requirements

### Requirement: frostui framework layer lives inside app module

The system SHALL provide a logically independent framework package at `com.lasercyber.lws.frostui` under `app/src/main/kotlin/`. The framework MUST NOT be delivered as a separate Gradle library module in this change. Source MUST be organized into exactly three top-level subpackages: `border`, `card`, and `dialog`, with dependency direction `dialog` → `card` → `border`.

#### Scenario: frostui does not depend on ui or ai packages

- **WHEN** frostui framework sources are compiled
- **THEN** no frostui source file MUST import `com.lasercyber.lws.ui` or `com.lasercyber.lws.ai`
- **AND** ui business code MAY import `com.lasercyber.lws.frostui`

#### Scenario: Three-layer package structure is enforced

- **WHEN** new frostui framework types are added
- **THEN** border drawing and design tokens MUST reside under `frostui.border`
- **AND** card, button, blur, and click-sound types MUST reside under `frostui.card`
- **AND** dialog overlay and prompt shell types MUST reside under `frostui.dialog`

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

### Requirement: card package provides composable container and button primitives

The `frostui.card` package SHALL provide `FrostCard`, `FrostButton`, and `FrostBlur` Composables (or equivalent public APIs) that compose `border` painting and live backdrop blur. `FrostButton` MUST support `default`, `primary`, and `secondary` variants and the shape and `borderGradientCenter` options required by `frosted-glass-components`.

#### Scenario: FrostCard renders blur and glass chrome

- **WHEN** `FrostCard` is shown over visible activity content with blur enabled
- **THEN** the card MUST show live blurred backdrop via BlurView or equivalent approved wrapper
- **AND** fill and border MUST use `border` package painters and split design tokens

#### Scenario: Java and XML interop is available

- **WHEN** a legacy Java Fragment or XML layout needs a frostui card
- **THEN** `frostui.card.interop` MUST provide a View wrapper (for example `FrostCardView`) embeddable without rewriting the host screen to Compose

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
