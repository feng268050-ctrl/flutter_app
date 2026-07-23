## ADDED Requirements

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

### Requirement: FrostedGlassButton provides reusable action control styling

The system SHALL provide a reusable `FrostedGlassButton` component for clickable HMI actions. The component MUST share FrostedGlass border/fill primitives with `FrostedGlassCard` while providing button-specific behavior including enabled, pressed, focused, and selected state rendering, text appearance defaults, minimum touch target sizing, shape configuration, custom border radius, and `default`, `primary`, and `secondary` visual variants. The `default` variant MUST use the same neutral glass color family as FrostedGlass dialog/card backgrounds, `primary` MUST use orange themed glass for confirmation actions, and `secondary` MUST use the neutral glass background with red-tinted text for destructive actions.

#### Scenario: Button preserves button interaction semantics
- **WHEN** a caller uses `FrostedGlassButton` in a layout
- **THEN** the view MUST behave as an accessible clickable button
- **AND** pressed, focused, disabled, and selected states MUST produce visible FrostedGlass-appropriate state feedback

#### Scenario: Default, primary, and secondary actions use shared style
- **WHEN** a caller configures a `FrostedGlassButton` as default, primary, or secondary
- **THEN** the component MUST apply the corresponding FrostedGlass emphasis level while retaining the shared glass fill and border foundation
- **AND** action buttons in dialogs and non-dialog screens MUST be able to share the same component implementation

#### Scenario: Button shape can be rounded or rectangular
- **WHEN** a caller configures `FrostedGlassButton` shape as `rounded`
- **THEN** the button MUST use the maximum available corner radius so square buttons render circular and wide buttons render capsule-shaped
- **AND** when the caller configures shape as `rectangle`, the button MUST use the standard small button corner radius

#### Scenario: Custom border radius overrides shape
- **WHEN** a caller sets a custom `borderRadius` on `FrostedGlassButton`
- **THEN** the button MUST use that radius for its glass fill, border, and click mask
- **AND** the explicit radius MUST take precedence over the rounded or rectangle shape setting

#### Scenario: Primary variant uses flat opaque emphasis fill
- **WHEN** a caller configures a `FrostedGlassButton` as `primary`
- **THEN** the button fill MUST use the shared primary orange token without a translucent vertical glass fade
- **AND** the border MUST use the primary orange border token set while retaining configurable `borderGradientCenter` behavior

#### Scenario: Secondary variant keeps neutral glass with red text
- **WHEN** a caller configures a `FrostedGlassButton` as `secondary`
- **THEN** the button MUST use the same neutral glass fill and border tokens as `default`
- **AND** the label MUST use the shared destructive red-tinted text token

### Requirement: FrostedGlassButton uses localized border rendering on rounded capsules

`FrostedGlassButton` SHALL enable localized border rendering when shape is `rounded` and no explicit `borderRadius` is set. Localized rendering MUST keep darker border regions visually subdued via a softened shadow base color while placing highlights only on the edge/corner pair named by `borderGradientCenter`.

#### Scenario: Diagonal centers use paired corner radial highlights
- **WHEN** a rounded `FrostedGlassButton` uses `top-left-bottom-right` or `bottom-left-top-right`
- **THEN** the border MUST render a soft-shadow base with paired radial highlights at the named diagonal corners
- **AND** highlights MUST NOT dominate the opposite diagonal corners on wide capsule buttons

#### Scenario: Axis-aligned centers use full-edge linear highlights
- **WHEN** a rounded `FrostedGlassButton` uses `top-bottom`
- **THEN** the border MUST highlight the full top and bottom edge regions
- **AND** the border MUST transition toward darker regions near the middle of the left and right edges

#### Scenario: Axis-aligned left-right centers use full-edge linear highlights
- **WHEN** a rounded `FrostedGlassButton` uses `left-right`
- **THEN** the border MUST highlight the full left and right edge regions
- **AND** the border MUST transition toward darker regions near the middle of the top and bottom edges

#### Scenario: Non-rounded buttons and cards keep shared sweep or linear shaders
- **WHEN** a `FrostedGlassButton` uses `rectangle` shape, a custom `borderRadius`, or a `FrostedGlassCard` renders a border
- **THEN** the consumer MUST NOT use the button localized-border code path
- **AND** border orientation MUST continue to use the shared sweep or axis-aligned linear shader implementation
