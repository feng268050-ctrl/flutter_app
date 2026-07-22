# app-page-status-bar Specification

## Purpose
Product adoption of CyberUI page status bar chrome on Monitor and Settings (shell and sub-pages), including this product’s current Wi‑Fi · Bluetooth · camera icon composition and shared glyphs with Home.

## Requirements
### Requirement: Non-Home product pages use the CyberUI page status bar

The App SHALL adopt the CyberUI **page status bar** for product Monitor and Settings surfaces (Settings shell and Settings sub-pages). The App MUST supply title, back handling (`onBack` that pops when the route can pop), and an ordered status-icon `items` list built from product-mapped UI phases. The App MUST NOT implement a parallel feature-local page status bar fork.

The bar MUST NOT block first paint on Wi‑Fi, Bluetooth, or camera I/O. Status glyphs remain informational in this capability (MUST NOT be required to navigate to Settings).

#### Scenario: Three regions are present on Monitor

- **WHEN** the operator opens the Monitor route
- **THEN** the CyberUI page status bar shows a back control on the left, the Monitor title centered, and status icons plus a compact clock on the right

#### Scenario: Three regions are present on Settings shell

- **WHEN** the operator opens the Settings route
- **THEN** the CyberUI page status bar shows a back control on the left, the Settings title centered, and status icons plus a compact clock on the right

#### Scenario: Settings sub-pages inherit the same bar

- **WHEN** the operator opens a Settings sub-page hosted by the shared Settings scaffold (for example Wi‑Fi)
- **THEN** the CyberUI page status bar shows back, that page’s title centered, and status icons plus a compact clock on the right

#### Scenario: Back pops when possible

- **WHEN** the operator activates the leading back control on a page that uses the CyberUI page status bar and can pop
- **THEN** the click sound plays
- **AND** the App’s `onBack` handler pops (or attempts to pop) the current route

### Requirement: This product composes the current three status icons into the strip

For this product’s current Home / Monitor / Settings adoption, the App SHALL build `CyberHomeStatusBar` `items` as **Wi‑Fi · Bluetooth · camera** (left to right), mapping live radio/adapter/session state into CyberUI icon phases. Wi‑Fi and Bluetooth MUST be hidden when radio/adapter is off. Camera glyph phases SHALL reflect the product IP-camera session UI status and MUST remain resolvable when Home is not mounted. This composition is a **product policy** for the current icon set; it MUST NOT imply that `CyberHomeStatusBar` is limited to three icons forever.

#### Scenario: Current product icon order then clock

- **WHEN** Wi‑Fi and Bluetooth radios/adapters are enabled
- **AND** the operator views Monitor or Settings chrome that uses the CyberUI page status bar
- **THEN** the trailing cluster shows Wi‑Fi, then Bluetooth, then camera, then the compact clock

#### Scenario: Wi‑Fi hidden when radio off

- **WHEN** Wi‑Fi radio state is **off**
- **AND** the operator views a page that uses the CyberUI page status bar
- **THEN** the Wi‑Fi status icon SHALL NOT be visible in the trailing cluster
- **AND** the compact clock SHALL remain visible

#### Scenario: Camera status without Home

- **WHEN** Home is not the current route
- **AND** the product IP-camera session reports a UI status
- **AND** the operator views Monitor or Settings chrome that uses the CyberUI page status bar
- **THEN** the camera glyph reflects that session UI status via the CyberUI camera status icon

### Requirement: Page and Home status chrome share CyberUI widgets

Monitor/Settings page chrome and Home’s top-right strip SHALL both use CyberUI status-bar widgets (`CyberPageStatusBar` / `CyberHomeStatusBar` and shared icons). The App MUST NOT maintain parallel Home-only or Settings-only glyph or strip forks. Home MAY keep a separate frost hero clock and overlay placement; the page status bar MUST NOT require that hero clock.

#### Scenario: Shared CyberUI Wi‑Fi glyph

- **WHEN** Wi‑Fi is associating or obtaining IP (or radio is starting)
- **AND** the operator compares Home’s `CyberHomeStatusBar` with Monitor or Settings page status bar trailing icons
- **THEN** both surfaces render the CyberUI Wi‑Fi status icon in a connecting / in-progress style
