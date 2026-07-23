## ADDED Requirements

### Requirement: FrostedGlass overlay cards use live BlurView backdrop

`FrostCardView` instances shown inside `FrostOverlayHost` dialog overlays SHALL use live `BlurView` against the activity `BlurTarget` (or equivalent capture root) as the primary backdrop blur mechanism. Bitmap snapshot blur MAY be used only when live `BlurView` setup fails.

#### Scenario: Prompt dialog shows live blur on open

- **WHEN** a `FrostedGlassDialog` prompt overlay is attached and the dialog card has backdrop blur enabled
- **THEN** the card MUST display live `BlurView` blur before any optional freeze
- **AND** MUST NOT block the UI thread on full-window CPU stack blur

#### Scenario: Overlay freeze stops BlurView updates

- **WHEN** the overlay host freezes the dialog backdrop after initial settle (triple-invalidate semantics)
- **THEN** the card MUST call `BlurView.setBlurAutoUpdate(false)` to retain the last GPU frame
- **AND** MUST NOT replace the live path with a new CPU stack-blurred full-screen bitmap as the default freeze mechanism

#### Scenario: Single BlurView per dialog card

- **WHEN** a frosted-glass prompt dialog is shown
- **THEN** exactly one `BlurView` layer on the dialog card MUST perform backdrop blur
- **AND** there MUST NOT be a separate outer `BlurView` wrapping the same card
