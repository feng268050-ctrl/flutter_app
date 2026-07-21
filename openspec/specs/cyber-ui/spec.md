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

### Requirement: Click backend honors App-persisted effect index

CyberUI SHALL keep `CyberClickSound` / `CyberClickSoundRegistry` as a fire-and-forget `playClick()` API (no index parameter on the registry). The product App’s registered backend SHALL select among multiple bundled click samples using the App-persisted sound-effect index. CyberUI MUST NOT hard-depend on `cyber_hal` or prefs files for click playback.

#### Scenario: Registry API stays index-free

- **WHEN** a Cyber control calls `CyberClickSoundRegistry.playClick()`
- **THEN** the call does not pass an effect index; sample selection is entirely inside the registered App backend

### Requirement: Phased FrostUI parity excluding IME

`packages/cyber_ui` SHALL grow until lws-ui FrostUI modules `border`, `button`, `control`, `dialog`, and `clock` have Cyber counterparts sufficient for product Settings/Home/Monitor chrome. **Soft-keyboard / CyberIME rendering remains out of `cyber_ui`** and is delivered by the separate `packages/cyber_ime` package (this change). Existing blur/card/click/volume APIs MUST remain and be extended rather than replaced wholesale. CyberUI dialog/overlay hosts MAY expose lift/refresh hooks for CyberIME composition without absorbing keyboard widgets.

#### Scenario: Module map lists control suite

- **WHEN** Phase B–D are complete
- **THEN** the package README module map lists switch, checkbox, slider, segmented, stepper, and dialog-host entries

#### Scenario: Keyboard lives in cyber_ime

- **WHEN** product code needs an HMI soft keyboard
- **THEN** it depends on `cyber_ime` rather than importing keyboard layouts from `cyber_ui`

