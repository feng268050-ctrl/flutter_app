## ADDED Requirements

### Requirement: FrostButtonPressFeedback provides shared press interaction

The system SHALL expose `FrostButtonPressFeedback` helpers in `com.lasercyber.lws.frostui.button` for Compose press alpha animation (resting 225/255 → pressed 1.0) and variant-aware bounded ripple. Ripple clipping MUST align to panel fill inset (half stroke width) so feedback matches glass chrome geometry. IME key caps MUST reuse these helpers instead of duplicating press curves.

#### Scenario: Default glass button shows alpha and ripple on press

- **WHEN** a user presses a `FrostButton` or `FrostButtonView` with `default` variant
- **THEN** the control MUST animate alpha from 225/255 to 1.0 over ~70ms
- **AND** a bounded white ripple MUST appear within the inset glass fill bounds

#### Scenario: IME keys share frost button press feedback

- **WHEN** the custom IME renders letter or action key caps
- **THEN** key press feedback MUST use `FrostButtonPressFeedback` modifiers
- **AND** MUST NOT implement independent alpha/ripple constants

### Requirement: FrostButtonTileRipple supports glass tile ripple overlays

The system SHALL provide `FrostButtonTileRipple.createTileRippleForeground(cornerRadiusPx)` for glass tiles backed by `FrostCardView` that need ripple feedback without full button chrome. Home quick-action and ripple-click entries MUST use this helper.

#### Scenario: Home tile ripple matches glass button ripple color

- **WHEN** a `FrostQuickActionEntry` or `FrostRippleClickEntry` sets its foreground ripple
- **THEN** it MUST call `FrostButtonTileRipple.createTileRippleForeground`
- **AND** MUST NOT reference deleted `FrostedGlassButton` ripple APIs

## MODIFIED Requirements

### Requirement: FrostButton provides reusable action control styling

The system SHALL provide reusable `FrostButton` (Compose) and `FrostButtonView` (XML/Java interop) components for clickable HMI actions. The components MUST share FrostedGlass border/fill primitives with `FrostCard` while providing button-specific behavior including enabled and pressed state rendering (alpha 225→255 plus bounded ripple), text appearance defaults, minimum touch target sizing, shape configuration, custom border radius, start/end icon support, and `default`, `primary`, `secondary`, and `light` visual variants. The `default` variant MUST use the same neutral glass color family as FrostedGlass dialog/card backgrounds, `primary` MUST use orange themed glass for confirmation actions, `secondary` MUST use the neutral glass background with red-tinted text for destructive actions, and `light` MUST use full-opacity styling with dark ripple for light-on-dark surfaces.

#### Scenario: Button preserves button interaction semantics

- **WHEN** a caller uses `FrostButtonView` in a layout
- **THEN** the view MUST behave as an accessible clickable button
- **AND** pressed and disabled states MUST produce visible FrostedGlass-appropriate state feedback including ripple

#### Scenario: Light variant for light overlay surfaces

- **WHEN** a caller configures a `FrostButton` as `light`
- **THEN** resting alpha MUST remain at full opacity
- **AND** ripple MUST use dark (black-tinted) feedback appropriate for light glass on dark backdrops

### Requirement: FrostButtonView is the canonical action control

All HMI frost action buttons MUST use `FrostButtonView` (XML/Java) or `FrostButton` (Compose). Tile-only ripple overlays MUST use `FrostButtonTileRipple.createTileRippleForeground`. The legacy `FrostedGlassButton` View class MUST NOT remain in the codebase.

#### Scenario: No duplicate button drawable implementation

- **WHEN** a developer adds or modifies a frost action button
- **THEN** they MUST use `FrostButton` / `FrostButtonView` backed by `frostui.border` painters
- **AND** standalone duplicate button background drawables MUST NOT be introduced

## REMOVED Requirements

### Requirement: FrostedGlass View components may delegate to frostui during migration

**Reason**: Migration complete; `FrostedGlassButton` deleted and all call sites use `FrostButtonView`.

**Migration**: Replace remaining `FrostedGlassButton` XML tags with `com.lasercyber.lws.frostui.button.interop.FrostButtonView`; update Java types and imports.
