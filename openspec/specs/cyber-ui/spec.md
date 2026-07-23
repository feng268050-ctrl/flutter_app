# cyber-ui Specification

## Purpose
TBD - created by archiving change p3-0-cyber-ui. Update Purpose after archive.
## Requirements
### Requirement: CyberUI package identity and layout

The shared Flutter UI kit SHALL live at `packages/cyber_ui` (in-repo path package for v1) with `publish_to: none`, SDK constraint compatible with `app/hmi`, and a public import surface under `package:cyber_ui/...`. Public types and widgets MUST use the **Cyber\*** prefix. Product Apps MUST depend on this package rather than forking glass widget implementations under feature folders.

#### Scenario: App declares CyberUI dependency

- **WHEN** the HMI App lists UI kit dependencies after this change
- **THEN** `app/hmi/pubspec.yaml` SHALL reference `cyber_ui` via a path dependency to `packages/cyber_ui`

#### Scenario: Public API naming

- **WHEN** a product feature imports glass chrome from the kit
- **THEN** imported public types use `Cyber*` names (not long-term public `Frost*` App APIs)

### Requirement: Backdrop sample modes

CyberUI SHALL expose `CyberBlurSampleMode` with at least `realtime`, `firstFrame`, and `onChange`. Glass surfaces that sample backdrop MUST accept a sample-mode parameter. Default for general glass chrome SHALL be `realtime` unless a factory documents otherwise (e.g. dialogs MAY default to `firstFrame`).

#### Scenario: Realtime uses compositor filter

- **WHEN** a Cyber glass widget is built with `sampleMode: realtime`
- **THEN** backdrop blur updates continuously via a compositor `BackdropFilter` (or package-equivalent) without requiring a frozen bitmap capture for that mode

#### Scenario: First-frame freezes after capture

- **WHEN** a Cyber glass widget is built with `sampleMode: firstFrame` and a backdrop capture root is available
- **THEN** the widget captures once after layout settle and freezes the blurred result

#### Scenario: On-change re-samples on token

- **WHEN** a Cyber glass widget is built with `sampleMode: onChange` and its sample token or controller generation changes
- **THEN** the widget re-captures and updates the frozen blur

#### Scenario: Missing capture root degrades safely

- **WHEN** first-frame or on-change mode cannot resolve a backdrop capture root or capture fails
- **THEN** the widget SHALL fall back to fake glass (semi-transparent fill/border) without crashing

### Requirement: Capture root scope and target

CyberUI SHALL provide a page-level backdrop scope and a capture target widget so consumers that are siblings of the wallpaper/GIF stack can still resolve the `RepaintBoundary` used for frozen sampling (lws-ui sibling capture-target pattern).

#### Scenario: Sibling consumer resolves target

- **WHEN** Home (or equivalent) wraps the page in `CyberBlurBackdropScope` and wallpaper layers in `CyberBlurBackdropTarget`
- **THEN** a sibling Cyber glass consumer under the same scope can resolve the capture boundary for first-frame / on-change modes

### Requirement: Core Cyber glass widgets (v1)

CyberUI v1 SHALL provide at least: backdrop blur applicator (`CyberBackdropBlur`), frosted card (`CyberCard`), status indicator (`CyberStatusIndicator`), and a dialog entry point (`showCyberDialog` or `CyberModal`). Widgets SHALL read shared theme tokens (intensity, tint, radius) from a documented Cyber theme seam.

#### Scenario: CyberCard renders frosted panel

- **WHEN** an App builds a `CyberCard` with child content
- **THEN** the card shows frosted glass chrome (blur + tint + clip) around the child

#### Scenario: Status indicator states

- **WHEN** an App builds `CyberStatusIndicator` with idle / success / failure (and optional in-progress) states
- **THEN** the indicator presents the corresponding Cyber status visual without requiring Material-only forks in the feature module

### Requirement: Design language seam

CyberUI SHALL isolate Frosted Glass look-and-feel behind a theme/renderer seam so a future design language can replace visuals without renaming CyberCard / CyberDialog call sites in product Apps.

#### Scenario: Theme override point exists

- **WHEN** integrators read CyberUI documentation
- **THEN** there is a single documented place to supply or override glass theme tokens / renderer registration for the subtree

### Requirement: No bare BackdropFilter in product features

Product feature modules SHALL NOT introduce new bare `BackdropFilter` usages for product glass; they MUST use CyberUI glass APIs instead.

#### Scenario: Home glass goes through CyberUI

- **WHEN** Home quick-action glass or equivalent Cyber glass is implemented after migration
- **THEN** the feature imports CyberUI blur/card APIs rather than calling `BackdropFilter` directly for that chrome

### Requirement: Click sound registry

CyberUI SHALL provide an injectable click-sound API aligned with lws-ui `FrostUiClickSoundRegistry`: a registerable `CyberClickSound` provider and `CyberClickSoundRegistry.playClick()`. Interactive Cyber controls that support click feedback (buttons, tappable cards, and later checkbox/segmented) SHALL call `playClick()` when `clickSoundEnabled` is true (default true). If no provider is registered, `playClick()` MUST be a no-op and MUST NOT throw. CyberUI MUST NOT hard-depend on `cyber_hal` media volume APIs for click playback; the product App registers the Linux/asset backend at startup.

#### Scenario: Unregistered provider is silent

- **WHEN** no click-sound provider has been registered
- **THEN** invoking `CyberClickSoundRegistry.playClick()` does nothing and does not throw

#### Scenario: Registered provider plays on control activate

- **WHEN** the App has registered a click-sound provider and the user activates a Cyber control with `clickSoundEnabled: true`
- **THEN** the registered provider’s click playback is invoked

#### Scenario: Click sound can be disabled per control

- **WHEN** a Cyber control is built with `clickSoundEnabled: false`
- **THEN** activating that control does not invoke `playClick()`

### Requirement: Click backend honors App-selected click sample

CyberUI SHALL keep `CyberClickSound` / `CyberClickSoundRegistry` as a fire-and-forget `playClick()` API (no asset/index parameter on the registry). The product App’s registered backend SHALL forward to HAL `ButtonFeedback.play()` (or equivalent App façade) so the active click asset is chosen outside CyberUI. CyberUI MUST NOT hard-depend on `cyber_hal` or prefs files for click playback.

#### Scenario: Registry API stays selection-free

- **WHEN** a Cyber control calls `CyberClickSoundRegistry.playClick()`
- **THEN** the call does not pass an effect index or asset key; sample selection is entirely inside the registered App backend / HAL

### Requirement: Phased FrostUI parity excluding IME

`packages/cyber_ui` SHALL grow until lws-ui FrostUI modules `border`, `button`, `control`, `dialog`, and `clock` have Cyber counterparts sufficient for product Settings/Home/Monitor chrome. **Soft-keyboard / CyberIME rendering remains out of `cyber_ui`** and is delivered by the separate `packages/cyber_ime` package (this change). Existing blur/card/click/volume APIs MUST remain and be extended rather than replaced wholesale. CyberUI dialog/overlay hosts MAY expose lift/refresh hooks for CyberIME composition without absorbing keyboard widgets.

#### Scenario: Module map lists control suite

- **WHEN** Phase B–D are complete
- **THEN** the package README module map lists switch, checkbox, slider, segmented, stepper, and dialog-host entries

#### Scenario: Keyboard lives in cyber_ime

- **WHEN** product code needs an HMI soft keyboard
- **THEN** it depends on `cyber_ime` rather than importing keyboard layouts from `cyber_ui`

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
