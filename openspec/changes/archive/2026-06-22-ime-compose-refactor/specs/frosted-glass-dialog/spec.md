## MODIFIED Requirements

### Requirement: IME interaction MUST NOT resize host background for input overlays

FrostedGlass overlays that host focusable text or numeric input fields SHALL prevent the host Activity content from being vertically compressed when the soft keyboard is visible. Implementation MUST use `com.lasercyber.lws.ime.core.ImeController` (or `FrostPromptConfig.imeConfig` which delegates to it) to temporarily adjust host `softInputMode` to `SOFT_INPUT_ADJUST_NOTHING` and apply IME insets to the overlay card via vertical translation rather than resizing the activity content root. Feature wrappers MUST NOT invoke legacy `FrostedGlassImeCoordinator` after migration is complete.

#### Scenario: Numeric input keyboard does not adjustResize host

- **WHEN** a `FrostedGlassNumericInputDialog` is showing and the IME opens
- **THEN** the host activity MUST NOT apply `adjustResize` layout shrinking to the page beneath the overlay
- **AND** the overlay card MUST remain interactable above the keyboard

#### Scenario: FrostPromptConfig enables IME session automatically

- **WHEN** an input overlay is shown with non-null `imeConfig` on `FrostPromptConfig`
- **THEN** `FrostOverlayHost` MUST attach and detach `ImeController` for the overlay lifecycle without requiring duplicate attach calls in the feature wrapper

## ADDED Requirements

### Requirement: Input overlays integrate imeConfig on FrostPromptConfig

`FrostPromptConfig` SHALL expose an optional `imeConfig: ImeConfig?`. When non-null, the frostui dialog layer MUST manage IME session attach and detach for the overlay card anchor.

#### Scenario: Text input dialog uses imeConfig

- **WHEN** `FrostedGlassTextInputDialog` is shown
- **THEN** it MUST configure `imeConfig` on the underlying prompt config
- **AND** MUST NOT manually call legacy IME coordinator attach or detach in the wrapper
