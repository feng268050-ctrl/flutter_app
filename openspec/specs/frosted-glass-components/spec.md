# frosted-glass-components Specification

## Purpose

Define reusable **FrostedGlass** container and action components. Card chrome is provided by `FrostCard` / `FrostCardView` in `com.lasercyber.lws.frostui.card`; action controls are provided by `FrostButton` / `FrostButtonView` in `com.lasercyber.lws.frostui.button`, sharing frosted-glass fill, border, and emphasis tokens used by `FrostedGlassDialog`, including configurable `borderGradientCenter` and button-specific localized border rendering for capsule-shaped controls.
## Requirements
### Requirement: FrostedGlassCard provides reusable glass container chrome

The system SHALL provide a reusable `FrostedGlassCard` component for HMI UI containers. The component MUST render the shared frosted-glass rounded card chrome, including translucent glass fill, optional border, rounded clipping, and configurable content padding/size values suitable for XML and programmatic use.

#### Scenario: Card renders shared glass foundation
- **WHEN** a layout includes `FrostedGlassCard` with default styling
- **THEN** the card MUST render using the shared frosted-glass fill, corner radius, and border tokens
- **AND** child content MUST be clipped or laid out within the rounded card bounds consistently with the current FrostedGlass dialog panel

#### Scenario: Card can disable border or fill independently
- **WHEN** a caller configures `FrostedGlassCard` to hide the border or fill
- **THEN** the component MUST preserve layout behavior while omitting only the requested visual layer
- **AND** other FrostedGlass visual tokens MUST remain unchanged

### Requirement: FrostedGlassCard supports borderGradientCenter

`FrostedGlassCard` SHALL expose a `borderGradientCenter` option with exactly these supported values: `top-left-bottom-right`, `bottom-left-top-right`, `top-bottom`, and `left-right`. The selected value MUST determine where the border highlight is centered and how it transitions toward darker or mid-tone border regions.

#### Scenario: Top-left and bottom-right border highlight
- **WHEN** `borderGradientCenter` is `top-left-bottom-right`
- **THEN** the border MUST highlight the top-left and bottom-right corner regions
- **AND** the border MUST transition toward less-highlighted regions along the adjacent edges

#### Scenario: Bottom-left and top-right border highlight
- **WHEN** `borderGradientCenter` is `bottom-left-top-right`
- **THEN** the border MUST highlight the bottom-left and top-right corner regions
- **AND** the border MUST transition toward less-highlighted regions along the adjacent edges

#### Scenario: Top and bottom border highlight
- **WHEN** `borderGradientCenter` is `top-bottom`
- **THEN** the border MUST highlight the top and bottom edge regions
- **AND** the border MUST transition toward darker or mid-tone regions near the middle of the left and right borders

#### Scenario: Left and right border highlight
- **WHEN** `borderGradientCenter` is `left-right`
- **THEN** the border MUST highlight the left and right edge regions
- **AND** the border MUST transition toward darker or mid-tone regions near the middle of the top and bottom borders

### Requirement: FrostButton provides reusable action control styling

The system SHALL provide reusable `FrostButton` (Compose) and `FrostButtonView` (XML/Java interop) components for clickable HMI actions. The components MUST share FrostedGlass border/fill primitives with `FrostCard` while providing button-specific behavior including enabled and pressed state rendering (alpha 225→255 plus bounded ripple), text appearance defaults, minimum touch target sizing, shape configuration, custom border radius, and `default`, `primary`, `secondary`, and `light` visual variants. The `default` variant MUST use the same neutral glass color family as FrostedGlass dialog/card backgrounds, `primary` MUST use orange themed glass for confirmation actions, and `secondary` MUST use the neutral glass background with red-tinted text for destructive actions.

#### Scenario: Button preserves button interaction semantics
- **WHEN** a caller uses `FrostButtonView` in a layout
- **THEN** the view MUST behave as an accessible clickable button
- **AND** pressed and disabled states MUST produce visible FrostedGlass-appropriate state feedback including ripple

#### Scenario: Default, primary, and secondary actions use shared style
- **WHEN** a caller configures a `FrostButton` as default, primary, or secondary
- **THEN** the component MUST apply the corresponding FrostedGlass emphasis level while retaining the shared glass fill and border foundation
- **AND** action buttons in dialogs and non-dialog screens MUST be able to share the same component implementation

#### Scenario: Button shape can be rounded or rectangular
- **WHEN** a caller configures `FrostButton` shape as `rounded`
- **THEN** the button MUST use the maximum available corner radius so square buttons render circular and wide buttons render capsule-shaped
- **AND** when the caller configures shape as `rectangle`, the button MUST use the standard small button corner radius

#### Scenario: Custom border radius overrides shape
- **WHEN** a caller sets a custom `borderRadius` on `FrostButtonView`
- **THEN** the button MUST use that radius for its glass fill, border, and click mask
- **AND** the explicit radius MUST take precedence over the rounded or rectangle shape setting

#### Scenario: Primary variant uses flat opaque emphasis fill
- **WHEN** a caller configures a `FrostButton` as `primary`
- **THEN** the button fill MUST use the shared primary orange token without a translucent vertical glass fade
- **AND** the border MUST use the primary orange border token set while retaining configurable `borderGradientCenter` behavior

#### Scenario: Secondary variant keeps neutral glass with red text
- **WHEN** a caller configures a `FrostButton` as `secondary`
- **THEN** the button MUST use the same neutral glass fill and border tokens as `default`
- **AND** the label MUST use the shared destructive red-tinted text token

### Requirement: FrostButton uses localized border rendering on rounded capsules

`FrostButton` SHALL enable localized border rendering when shape is `rounded` and no explicit `borderRadius` is set. Localized rendering MUST keep darker border regions visually subdued via a softened shadow base color while placing highlights only on the edge/corner pair named by `borderGradientCenter`.

#### Scenario: Diagonal centers use paired corner radial highlights
- **WHEN** a rounded `FrostButton` uses `top-left-bottom-right` or `bottom-left-top-right`
- **THEN** the border MUST render a soft-shadow base with paired radial highlights at the named diagonal corners
- **AND** highlights MUST NOT dominate the opposite diagonal corners on wide capsule buttons

#### Scenario: Axis-aligned centers use full-edge linear highlights
- **WHEN** a rounded `FrostButton` uses `top-bottom`
- **THEN** the border MUST highlight the full top and bottom edge regions
- **AND** the border MUST transition toward darker regions near the middle of the left and right edges

#### Scenario: Axis-aligned left-right centers use full-edge linear highlights
- **WHEN** a rounded `FrostButton` uses `left-right`
- **THEN** the border MUST highlight the full left and right edge regions
- **AND** the border MUST transition toward darker regions near the middle of the top and bottom edges

#### Scenario: Non-rounded buttons and cards keep shared sweep or linear shaders
- **WHEN** a `FrostButton` uses `rectangle` shape, a custom `borderRadius`, or a `FrostCard` renders a border
- **THEN** the consumer MUST NOT use the button localized-border code path
- **AND** border orientation MUST continue to use the shared sweep or axis-aligned linear shader implementation

### Requirement: frostui provides canonical Compose implementation for glass components

The system SHALL implement the visual and interaction contract of legacy glass card and button View components as `FrostCard` (`frostui.card`) and `FrostButton` (`frostui.button`) Composables backed by `frostui.border` painters. These Composables MUST be the canonical implementation for new frostui-based UI. Visual tokens MUST be sourced from split `frostui_*` resource files.

#### Scenario: FrostCard matches FrostedGlassCard visual contract

- **WHEN** `FrostCard` is rendered with default styling
- **THEN** it MUST use the shared frosted-glass fill, corner radius, and border tokens
- **AND** child content MUST be clipped within rounded card bounds consistent with the existing dialog panel

#### Scenario: FrostButton matches legacy glass button variants

- **WHEN** `FrostButton` is configured as `default`, `primary`, or `secondary`
- **THEN** emphasis styling MUST match the corresponding variant rules in this specification
- **AND** rounded capsule buttons MUST use localized border rendering per the existing localized-border requirement

### Requirement: FrostButtonView is the canonical action control

All HMI frost action buttons MUST use `FrostButtonView` (XML/Java) or `FrostButton` (Compose). Tile-only ripple overlays MUST use `FrostButtonTileRipple.createTileRippleForeground`. The legacy `FrostedGlassButton` View class MUST NOT remain in the codebase.

#### Scenario: No duplicate button drawable implementation

- **WHEN** a developer adds or modifies a frost action button
- **THEN** they MUST use `FrostButton` / `FrostButtonView` backed by `frostui.border` painters
- **AND** standalone duplicate button background drawables MUST NOT be introduced

### Requirement: Input overlay stepper controls use FrostButton glass interaction

Numeric and other input overlay bodies that expose in-body stepper or auxiliary action controls (for example `FrostNumericStepper` minus and plus buttons) SHALL render those controls with `com.lasercyber.lws.frostui.card.FrostButton` (or equivalent frostui Compose API) so they share FrostedGlass border/fill primitives, visible press interaction, and click sound via `FrostUiClickSoundRegistry`. Stepper controls MUST NOT use plain `TextView` plus legacy drawable-only backgrounds as the long-term implementation.

#### Scenario: Numeric stepper minus and plus use FrostButton

- **WHEN** `FrostNumericStepper` renders with `showStepper = true`
- **THEN** the minus and plus controls MUST be implemented as `FrostButton` with `FrostButtonVariant.DEFAULT`
- **AND** tapping either control MUST play the shared frostui click sound and apply the existing step increment/decrement logic

#### Scenario: Stepper buttons use default glass not primary orange

- **WHEN** stepper minus or plus buttons are rendered in an input overlay body
- **THEN** they MUST use the default/neutral glass variant
- **AND** MUST NOT use `FrostButtonVariant.PRIMARY` orange styling reserved for confirmation actions

### Requirement: Custom IME Enter key uses FrostButton PRIMARY orange variant

The custom in-app IME Enter key on the keyboard bottom row MUST always use `FrostButtonVariant.PRIMARY` with the shared primary orange fill and border tokens defined for FrostedGlass confirmation buttons, independent of whether the key face shows text, an icon, or both.

#### Scenario: IME Enter uses primary orange styling for text face

- **WHEN** the custom IME Enter key is configured with text-only display
- **THEN** the Enter key MUST use `FrostButtonVariant.PRIMARY`
- **AND** MUST match the primary orange token styling in this specification

#### Scenario: IME Enter uses primary orange styling for icon face

- **WHEN** the custom IME Enter key is configured with icon-only display
- **THEN** the Enter key MUST still use `FrostButtonVariant.PRIMARY`
- **AND** MUST NOT fall back to default glass key styling used for letter keys

### Requirement: Input dialog primary confirm uses FrostButton PRIMARY orange variant

When an input overlay shows an on-screen primary confirm action in the dialog action slot (in addition to the custom IME Enter key), that control MUST use `FrostButtonVariant.PRIMARY` with the shared primary orange fill and border tokens defined for FrostedGlass confirmation buttons.

#### Scenario: Numeric dialog confirm is primary orange

- **WHEN** a numeric input overlay displays a confirm action in the prompt action bar
- **THEN** the confirm button MUST use `FrostButtonVariant.PRIMARY`
- **AND** MUST match the primary orange token styling in `frosted-glass-components`

#### Scenario: WiFi password has no on-screen primary confirm

- **WHEN** the WiFi password overlay is shown per `wifi-password-connect-dialog`
- **THEN** the dialog MUST NOT show a separate on-screen Connect button
- **AND** primary submission MUST occur through the IME custom connect action only

