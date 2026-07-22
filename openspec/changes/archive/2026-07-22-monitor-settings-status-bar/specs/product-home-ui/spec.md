## ADDED Requirements

### Requirement: Home hosts the CyberUI Home status bar

Product Home’s top-right status strip SHALL be CyberUI **`CyberHomeStatusBar`** (not a feature-local strip or icon-font fork). The App SHALL map HAL / session state into CyberUI UI phases and compose this product’s **current** icon set (**Wi‑Fi · Bluetooth · camera**) into the bar’s ordered `items`, then position `CyberHomeStatusBar` in Home’s existing top-right overlay slot. The Home status bar background MUST remain transparent over the Home wallpaper. Home MAY keep its frost hero clock and Stack placement; this requirement does not force Home to adopt the CyberUI page status bar layout. Additional future Home status icons MUST be addable by extending the `items` list without replacing `CyberHomeStatusBar`.

#### Scenario: Home Wi‑Fi uses CyberHomeStatusBar

- **WHEN** Wi‑Fi connection phase is associating or obtaining IP
- **AND** the operator views Home
- **THEN** the Home top-right strip is `CyberHomeStatusBar` showing a connecting / in-progress Wi‑Fi style among this product’s current icons

#### Scenario: Home status bar stays transparent

- **WHEN** the operator views Home
- **THEN** `CyberHomeStatusBar` does not cover the Home wallpaper with an opaque bar fill

#### Scenario: Home does not fork status chrome

- **WHEN** integrators inspect Home status-bar presentation after this change
- **THEN** the bar and status glyphs come from `package:cyber_ui` rather than feature-local status-bar forks
