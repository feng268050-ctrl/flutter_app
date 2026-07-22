## ADDED Requirements

### Requirement: CyberUI provides state-driven status-bar icons

CyberUI SHALL provide presentational **status-bar icon** widgets under an `icons` module (sources under `packages/cyber_ui/lib/src/icons/`, exported on the public `cyber_ui` import surface). The kit MUST include at least these starter icons for current products:

- A Wi‑Fi status icon driven by a connectivity UI phase (`hidden` / `connecting` / `connected` / `onIdle`) and optional signal strength for connected bars
- A Bluetooth status icon driven by the same connectivity UI phase
- A camera link status icon driven by camera UI states (`connecting` / `connected` / `failed`)

These widgets MUST render from **UI status enums** (or equivalent CyberUI status types) and MUST NOT depend on product HAL controllers, Wi‑Fi/Bluetooth platform models, or App IP-camera session types. Public types MUST use the `Cyber*` prefix. When the connectivity phase is `hidden`, the Wi‑Fi and Bluetooth icons MUST occupy no visible glyph (shrink / empty). The icon module MUST allow additional status icon widgets to be added later without changing the `CyberHomeStatusBar` slot API.

#### Scenario: Wi‑Fi icon follows phase

- **WHEN** an App builds the CyberUI Wi‑Fi status icon with phase `connecting`
- **THEN** the widget shows a connecting / in-progress Wi‑Fi visual
- **AND** when phase is `hidden` the Wi‑Fi glyph is not visible

#### Scenario: Bluetooth icon follows phase

- **WHEN** an App builds the CyberUI Bluetooth status icon with phase `connected`
- **THEN** the widget shows a connected-style Bluetooth visual

#### Scenario: Camera icon follows link state

- **WHEN** an App builds the CyberUI camera status icon with state `failed`
- **THEN** the widget shows the failed camera-link visual (base glyph plus failure mark)

#### Scenario: No HAL types in CyberUI icons

- **WHEN** integrators inspect the CyberUI status icon public API
- **THEN** the icon constructors accept CyberUI UI status types (and simple value params such as size / dBm)
- **AND** they do not require `WifiController`, Bluetooth controller, or App IP-camera session types

### Requirement: CyberUI provides an extensible Home status bar

CyberUI SHALL provide a reusable **Home status bar** widget (`CyberHomeStatusBar`) that lays out an **ordered list of status icon children** (slots) in a right-aligned row with consistent spacing for Home-style overlays. The public API MUST accept a list (or equivalent ordered collection) of widgets and MUST NOT hard-code a fixed closed set of exactly three named icon parameters as the only way to populate the bar. The bar’s background MUST be **transparent** (no opaque fill or plate behind the icons) so it can overlay Home wallpaper. The bar MUST NOT subscribe to product HAL controllers. Public type MUST use the `Cyber*` prefix.

Starter CyberUI icons (Wi‑Fi, Bluetooth, camera) are composed **into** `CyberHomeStatusBar` by the App (or by a convenience helper); they are not the permanent upper bound on bar contents.

#### Scenario: Home status bar lays out supplied items in order

- **WHEN** an App builds `CyberHomeStatusBar` with an ordered `items` list of three visible status icons
- **THEN** the bar shows those icons left-to-right in the given order as a single spaced row

#### Scenario: Home status bar accepts more than three icons

- **WHEN** an App builds `CyberHomeStatusBar` with more than three status icon children
- **THEN** the bar lays out all supplied items with the same spacing rules
- **AND** the API does not require a new named parameter per additional icon

#### Scenario: Home status bar background is transparent

- **WHEN** an App places `CyberHomeStatusBar` over a non-uniform Home background
- **THEN** the bar does not paint an opaque background plate
- **AND** the underlying Home content remains visible between/around the icons

#### Scenario: Home status bar is HAL-agnostic

- **WHEN** an App supplies status icon widgets to `CyberHomeStatusBar`
- **THEN** the bar renders without requiring Wi‑Fi or Bluetooth controller instances

### Requirement: CyberUI provides a page status bar

CyberUI SHALL provide a reusable **page status bar** suitable for non-Home product routes (`PreferredSizeWidget` / AppBar-equivalent chrome) with:

1. **Leading** — optional back control that plays the CyberUI click sound and invokes an App-supplied `onBack` callback (CyberUI MUST NOT call `Navigator` directly)
2. **Center** — page title
3. **Trailing** — `CyberHomeStatusBar` (or the same extensible icon-slot layout) followed by a compact minute-resolution local-time clock

The page status bar MUST reuse `CyberHomeStatusBar` (or a shared layout helper) so spacing/icon composition stays consistent with Home. It MUST accept chrome params (title, back callback, status icon items, optional `bottom` / extra actions) without baking a fixed three-icon-only trailing API. Extra actions, when supported, MUST NOT displace the far-right status+clock cluster.

The page status bar background MUST **adapt to the page’s primary chrome color**: by default it SHALL resolve from the ambient Material theme (prefer `AppBarTheme.backgroundColor`, otherwise a documented surface/scaffold-equivalent theme color). It MUST also accept an optional explicit `backgroundColor` (or equivalent) property so an App can override the fill to match a specific page primary without forking the widget. Public type MUST use the `Cyber*` prefix (e.g. `CyberPageStatusBar`).

#### Scenario: Three regions

- **WHEN** an App builds the CyberUI page status bar with a title, `onBack`, and a non-empty status icon `items` list
- **THEN** the bar shows back on the left, the title centered, and the status icons plus a compact clock on the right

#### Scenario: Back uses callback not Navigator

- **WHEN** the operator activates the page status bar back control
- **THEN** CyberUI plays the click sound
- **AND** CyberUI invokes the supplied `onBack` callback
- **AND** CyberUI does not itself call `Navigator.pop`

#### Scenario: Clock updates at minute resolution

- **WHEN** a CyberUI page status bar remains mounted across a local minute boundary
- **THEN** the compact clock text updates to the new minute

#### Scenario: Page bar trailing Home status bar is extensible

- **WHEN** an App passes four status icon widgets as the page status bar trailing `CyberHomeStatusBar` items
- **THEN** all four icons appear before the compact clock
- **AND** no CyberUI API change is required beyond supplying a longer `items` list

#### Scenario: Page bar background follows theme by default

- **WHEN** an App builds `CyberPageStatusBar` without an explicit background override
- **AND** the ambient theme defines an AppBar / surface chrome color
- **THEN** the page status bar background uses that theme-derived page chrome color

#### Scenario: Page bar background accepts explicit override

- **WHEN** an App builds `CyberPageStatusBar` with an explicit `backgroundColor` (or equivalent)
- **THEN** the page status bar background uses that color instead of the default theme resolution
