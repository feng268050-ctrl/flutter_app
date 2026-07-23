## MODIFIED Requirements

### Requirement: Liquid glass shell uses live blur and shared visual tokens

The dialog SHALL render as an in-window overlay attached to the hosting `Activity` content root (via `FrostedGlassOverlayHost`), with:

- Semi-transparent scrim (`frosted_glass_scrim`)
- `BlurView` card with rounded clip (`frosted_glass_rounded_clip`, `frosted_glass_corner_radius`)
- Glass fill and configurable border drawn through the shared `FrostedGlassCard` foundation
- Typography and buttons using `frosted_glass_text_*`, shared `FrostedGlassButton` styling, and `frosted_glass_divider` resources

`FrostedGlassDialog` and other FrostedGlass-style dialog wrappers MUST use the shared `FrostedGlassCard` foundation for card chrome instead of applying separate ad-hoc panel background/foreground drawables directly to dialog content. Prompt dialogs MAY dismiss on scrim tap when `dismissOnScrimClick(true)`; blocking flows (for example in-progress correction) SHALL disable scrim dismiss.

#### Scenario: Overlay blurs activity content behind the card
- **WHEN** `FrostedGlassDialog` is shown over a visible activity
- **THEN** the card background MUST show live blurred content from the activity (not an opaque flat panel only)
- **AND** the card MUST respect the shared 雾化玻璃设计 corner radius and border styling
- **AND** the card chrome MUST be supplied by the shared `FrostedGlassCard` foundation

#### Scenario: Blocking progress disables scrim dismiss
- **WHEN** a long-running operation shows a 雾化玻璃设计 dialog that must not dismiss accidentally
- **THEN** the caller MUST set `dismissOnScrimClick(false)`
- **AND** explicit cancel (action slot or programmatic dismiss) remains the dismissal path

#### Scenario: Dialog action buttons use shared FrostedGlassButton styling
- **WHEN** `FrostedGlassDialog` renders its default action slot
- **THEN** confirm and cancel actions MUST use the shared FrostedGlass button styling
- **AND** existing confirm/cancel visibility, text, and callback behavior MUST remain unchanged

#### Scenario: Default prompt actions use standardized FrostedGlass button chrome
- **WHEN** `dialog_frosted_glass_prompt.xml` renders cancel and confirm actions
- **THEN** both actions MUST use `borderGradientCenter="top-left-bottom-right"`
- **AND** cancel MUST use the `default` variant while confirm MUST use the `primary` variant

#### Scenario: Startup self-check close action uses shared FrostedGlass button styling
- **WHEN** the Startup Self-Check custom body renders its close control
- **THEN** the close action MUST use `FrostedGlassButton` with `default` variant and `top-left-bottom-right` border orientation
- **AND** existing close visibility, text, and callback behavior MUST remain unchanged

### Requirement: Safety tips screens adopt shared FrostedGlass components

Safety Operations Tips and Product Use Disclaimer screens SHALL use the shared FrostedGlass component foundation for their main card container and agree action.

#### Scenario: Safety tips card and agree action use shared components
- **WHEN** `activity_safety_tips.xml` or `activity_use_safety_tips.xml` is inflated
- **THEN** the main content container MUST use `FrostedGlassCard`
- **AND** the agree action MUST use `FrostedGlassButton` with `primary` variant and `top-left-bottom-right` border orientation

#### Scenario: Product use disclaimer link remains a text link
- **WHEN** Safety Operations Tips renders the Product Use Disclaimer entry point
- **THEN** that control MUST remain a text link rather than a `FrostedGlassButton`
- **AND** only the agree action adopts the shared button component
