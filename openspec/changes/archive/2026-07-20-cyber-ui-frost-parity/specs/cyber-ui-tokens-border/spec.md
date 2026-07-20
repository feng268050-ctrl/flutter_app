## ADDED Requirements

### Requirement: Cyber glass tokens and dimens

`packages/cyber_ui` SHALL expose shared design tokens aligned with lws-ui `FrostColors` / `FrostDimens` / `FrostTone` (Cyber-named), consumable via `CyberGlassTheme` and/or dedicated token classes. Product features MUST use these tokens for new glass chrome rather than hard-coding one-off colors.

#### Scenario: Theme provides default tokens

- **WHEN** an App builds `ThemeData` with `CyberGlassTheme`
- **THEN** Cyber cards/controls can resolve default intensity, tint, border, and corner radius from the theme

### Requirement: Panel border and fill primitives

CyberUI SHALL provide panel border/fill primitives suitable for cards and dialog shells (stand-ins for lws-ui `border/` painters). Full bitmap-shader parity MAY be approximated with Flutter `Border` / gradients when RK3566 cost requires it; fake-glass fallback MUST remain available.

#### Scenario: Card can use Cyber border tokens

- **WHEN** a `CyberCard` (or shell) is built with default theme tokens
- **THEN** it renders a bordered frosted panel without the App supplying ad-hoc border colors
