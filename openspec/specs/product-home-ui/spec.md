# product-home-ui Specification

## Purpose
TBD - created by archiving change home-settings-ui. Update Purpose after archive.
## Requirements
### Requirement: Product Home is the launcher screen

The Flutter HMI app SHALL present a product Home screen as the initial route after `runApp`. The Home screen SHALL visually reference lws-ui Home composition for the in-scope elements only: full-screen static backdrop, dual animated hero overlays, and a Settings entry. Home MUST NOT require Modbus, GPIO, audio engine, or backlight I/O before first paint.

#### Scenario: Launcher shows product Home

- **WHEN** flutter-pi renders the app initial route
- **THEN** the user sees the product Home backdrop (not the P2 Demo scroll as the primary home)

#### Scenario: First paint is not blocked by platform I/O

- **WHEN** Home builds its first frame
- **THEN** Modbus, GPIO LED setup, media audio open, and backlight sysfs access have not been required to complete before that frame

### Requirement: Home shows static backdrop and dual animated overlays

The Home screen SHALL display a full-screen static background image and left/right animated WebP (or equivalent multi-frame) overlays sourced from bundled assets aligned with lws-ui `home_back` / `home_left_400` / `home_right_400`. Decode SHOULD target the asset canvas size (200×200) rather than the layout size. If animation decode fails on device, the screen SHALL still show the static backdrop (and static frames if available) without crashing.

#### Scenario: Backdrop and overlays visible

- **WHEN** the user views Home after assets load
- **THEN** the static backdrop and left/right animated overlays are visible in a layout consistent with lws-ui Home layering

#### Scenario: Animation failure is non-fatal

- **WHEN** animated overlay decode fails
- **THEN** Home remains usable and the Settings entry stays available

### Requirement: Home provides Settings entry

The Home screen SHALL provide a visible Settings affordance that navigates to the product Settings route, and a visible Monitor affordance that navigates to the product Monitor route. Home MUST NOT, in this capability, require Quick Mode, Engineer Mode, AI Vision, metric stat cards, or status-bar chrome as full product flows (display-only stubs MAY exist for Quick/Engineer).

#### Scenario: Settings entry navigates

- **WHEN** the user activates the Settings entry on Home
- **THEN** the app navigates to the Settings route

#### Scenario: Monitor entry navigates

- **WHEN** the user activates the Monitor entry on Home
- **THEN** the app navigates to the Monitor route

#### Scenario: Deferred home chrome absent

- **WHEN** the user views Home after this change
- **THEN** Quick Mode, Engineer Mode, AI Vision, and the four customizable stat cards are not required to be present as full product flows (display-only stubs MAY exist)

### Requirement: Home does not host engineering perf HUD

Product Home MUST NOT present the Home-local engineering perf HUD strip (single-line UI/raster/panel FPS + SoC/GPU temperatures). Those host metrics SHALL be provided by the global system status card overlay when Show System Status Overlay is enabled. Home first paint MUST remain free of blocking sysInfo I/O. By default (preference off), Home SHALL NOT show host engineering FPS/thermal chrome.

#### Scenario: Home has no local perf HUD strip

- **WHEN** the user views product Home after this change
- **THEN** Home does not render the former top-left single-line FPS + SoC/GPU engineering strip as a Home-owned widget

#### Scenario: Host metrics available via overlay when enabled

- **WHEN** Show System Status Overlay is enabled
- **AND** the user views any product route
- **THEN** UI/raster/panel FPS and SoC/GPU temperatures are available via the global system status card without opening the Demo route

### Requirement: Home glass chrome uses CyberUI

Product Home frosted surfaces (quick-action cards, and any Cyber glass used by the home clock composition) SHALL use `packages/cyber_ui` APIs (`CyberBackdropBlur` / `CyberCard` / shared sample-mode types) rather than duplicating glass implementations under `app/hmi/lib/ui/cyber` after migration. Home MUST keep a backdrop capture scope/target so frozen/on-change modes remain available when selected.

#### Scenario: Quick actions use CyberUI sample mode

- **WHEN** the user views Home quick-action Monitor / Settings / AI Vision cards after CyberUI migration
- **THEN** those cards obtain frost via CyberUI widgets configured with an explicit `CyberBlurSampleMode` (product default realtime)

#### Scenario: Home declares CyberUI dependency

- **WHEN** the App builds Home after this change
- **THEN** Home presentation code imports glass primitives from `package:cyber_ui/...` (not a forked copy under feature-local folders)

### Requirement: Home tappable chrome may play Cyber click sound

Home quick-action activations (Monitor / Settings / AI Vision) SHALL go through CyberUI tappable chrome that honors click-sound enablement once CyberUI click registry is wired. The App SHALL register a click-sound backend at startup when product click feedback is enabled.

#### Scenario: Quick action tap can trigger click sound

- **WHEN** a click-sound provider is registered and the user activates a Home quick-action card with click sound enabled
- **THEN** CyberUI click playback is invoked as part of the activation path

### Requirement: Home clock consumes Cyber clock API

After the Cyber clock API lands, product Home clock chrome SHALL use that API for frost/appearance instead of duplicating glyph-frost implementation solely under App feature code. App MAY retain layout/position composition.

#### Scenario: Home clock imports cyber_ui clock

- **WHEN** Phase F/G are complete
- **THEN** Home clock rendering depends on the Cyber clock API for frost glyphs/appearance tokens

### Requirement: Home may overlay boot self-check after first paint

Product Home SHALL remain the launcher and first-paint target. When boot self-check is enabled and not yet completed in-process, Home MAY present the self-check dialog as an overlay after the first frame without delaying Home’s initial paint on Modbus or camera I/O.

#### Scenario: First paint does not wait on self-check Modbus

- **WHEN** the App navigates to Home as the initial route
- **THEN** Home chrome SHALL paint without waiting for the self-check Modbus snapshot to complete
- **AND** the self-check dialog, if shown, SHALL appear as a subsequent overlay

