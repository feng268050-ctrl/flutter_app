# cyber-ui-tokens-border Specification

## Purpose

Shared Cyber glass tokens and panel outline primitives aligned with lws-ui
`FrostColors` / `FrostDimens` / `FrostTone` / `PanelBorderPainter`. Structure
prefers Material `Card` + `BorderSide` or a light `CustomPaint` gradient stroke;
full bitmap-shader parity is not required on RK3566.

## Requirements

### Requirement: Cyber glass tokens and dimens

`packages/cyber_ui` SHALL expose shared design tokens aligned with lws-ui `FrostColors` / `FrostDimens` / `FrostTone` (Cyber-named), consumable via `CyberGlassTheme` and/or dedicated token classes. Product features MUST use these tokens for new glass chrome rather than hard-coding one-off colors.

Default card corner radius SHALL be **28**. Card stroke width SHALL be at least **1** (readable on dark HMI). Button stroke SHALL be **1**. Rectangle button corner radius SHALL be **14**.

#### Scenario: Theme provides default tokens

- **WHEN** an App builds `ThemeData` with `CyberGlassTheme`
- **THEN** Cyber cards/controls can resolve default intensity, tint, border, and corner radius from the theme

#### Scenario: Corner radius matches Frost card

- **WHEN** an App uses default `CyberDimens.cornerRadius` / `CyberGlassTheme.cornerRadius`
- **THEN** the value is 28

### Requirement: Panel border and fill primitives

CyberUI SHALL provide panel border/fill primitives suitable for cards and dialog shells (`CyberPanelBorder`, `CyberPanelOutline`, `CyberOutlinedPanel`). Frost-style outlines SHALL use Flutter `LinearGradient` / `RadialGradient` (or Material `BorderSide` for uniform) on a round-rect stroke — not a unidirectional three-stop fade. Fake-glass fallback MUST remain available. Outlines MUST remain visible on dark HMI backgrounds (uniform stroke contrast at least comparable to `CyberColors.borderUniform`).

#### Scenario: Card can use Cyber border tokens

- **WHEN** a `CyberCard` (or shell) is built with default theme tokens
- **THEN** it renders a bordered frosted panel without the App supplying ad-hoc border colors

#### Scenario: Frost gradient outline is bidirectional

- **WHEN** a panel uses `CyberPanelOutlineStyle.frostGradient` with an axis center (`topBottom` / `leftRight`)
- **THEN** the outline paints a symmetric H → blend → S → blend → H linear stroke (highlights on both ends)

#### Scenario: Diagonal outline uses dual corner radials

- **WHEN** a panel uses a diagonal `CyberBorderGradientCenter`
- **THEN** the outline paints a shadow baseline plus radial highlights at the two opposing corners
- **AND** each corner radial radius is about **0.5 × the short side** of the panel

#### Scenario: Border gradient center is selectable

- **WHEN** a panel or button sets `CyberBorderGradientCenter` (or Settings `borderGradientCenter`)
- **THEN** highlight placement follows that center (not one shared unidirectional diagonal for every card)

#### Scenario: Uniform outline uses Material side

- **WHEN** a panel uses `CyberPanelOutlineStyle.uniform`
- **THEN** the Material `Card` shape carries a non-zero `BorderSide`
