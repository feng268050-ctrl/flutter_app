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

The Home screen SHALL provide a visible Settings affordance that navigates to the product Settings route, and a visible Monitor affordance that navigates to the product Monitor route. Home MUST NOT, in this capability, require Quick Mode, Engineer Mode, AI Vision, or metric stat cards as full product flows (display-only stubs MAY exist for Quick/Engineer). Home SHALL include the top-right status-bar strip with the camera link status icon and the Wi‑Fi / Bluetooth status icons per the requirements in this capability. Other status-bar chrome (recording, remote lock) remains optional for later slices.

#### Scenario: Settings entry navigates

- **WHEN** the user activates the Settings entry on Home
- **THEN** the app navigates to the Settings route

#### Scenario: Monitor entry navigates

- **WHEN** the user activates the Monitor entry on Home
- **THEN** the app navigates to the Monitor route

#### Scenario: Deferred home chrome absent except status-bar icons

- **WHEN** the user views Home after this change
- **THEN** Quick Mode, Engineer Mode, AI Vision, and the four customizable stat cards are not required to be present as full product flows (display-only stubs MAY exist)
- **AND** the top-right status-bar strip SHALL present the camera link icon and Wi‑Fi / Bluetooth icons as specified

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

### Requirement: Home shows top-right camera link status icon

Product Home SHALL display a camera link status icon in the top-right **status-bar strip** (design canvas aligned with lws-ui Home chrome near the historical Wi‑Fi icon slot). The icon SHALL reflect the **product IP-camera session** UI phase (`connecting` / `connected` / `failed`) and MUST NOT block Home first paint. The glyph SHOULD be composed from icon-font layers (camera base plus connecting spinner and/or failure mark) rather than requiring new bitmap assets. Within the strip, the camera glyph SHALL remain the rightmost of the Wi‑Fi / Bluetooth / camera set.

Visual mapping:

- **connected** — illuminated / full-opacity camera glyph
- **connecting** — camera glyph with an appropriate in-progress animation (spinner or rotating accent)
- **failed** — camera glyph with a red X (or equivalent cancel mark) overlay after the attempt budget is exhausted

#### Scenario: Connected shows lit camera

- **WHEN** product IP-camera UI phase is **connected**
- **AND** the operator views Home
- **THEN** the top-right camera icon SHALL appear in the lit/connected style without a failure mark

#### Scenario: Connecting shows progress animation

- **WHEN** product IP-camera UI phase is **connecting**
- **AND** the operator views Home
- **THEN** the top-right camera icon SHALL show an in-progress animation

#### Scenario: Failed shows camera with red X

- **WHEN** product IP-camera UI phase is **failed**
- **AND** the operator views Home
- **THEN** the top-right camera icon SHALL show a camera glyph with a red failure mark

#### Scenario: Status icon does not block first paint

- **WHEN** Home builds its first frame
- **THEN** rendering the camera status icon MUST NOT await eth0 configure, ICMP, or MediaMTX start completion

#### Scenario: Camera is rightmost in the strip

- **WHEN** Wi‑Fi and/or Bluetooth status icons are visible alongside the camera icon
- **AND** the operator views Home
- **THEN** the camera icon SHALL be the rightmost glyph in the status-bar strip

### Requirement: Home hosts a top-right status-bar strip

Product Home SHALL render connectivity and link status glyphs inside a single top-right **status-bar strip** (right-aligned row with consistent spacing) rather than as independent one-off overlays for each glyph. The strip SHALL host at least the camera link icon and the Wi‑Fi / Bluetooth icons required by this capability. Home first paint MUST NOT block on Wi‑Fi, Bluetooth, or camera I/O to decide strip layout geometry.

#### Scenario: Strip is the status chrome host

- **WHEN** the operator views Home
- **THEN** camera and enabled connectivity status glyphs appear within the top-right status-bar strip
- **AND** Home does not rely on separate ad-hoc top-right overlays for those glyphs

#### Scenario: Strip layout does not block first paint

- **WHEN** Home builds its first frame
- **THEN** laying out the status-bar strip MUST NOT await Wi‑Fi scan, Bluetooth discovery, eth0 configure, or camera health completion

### Requirement: Home shows Wi‑Fi status icon when radio is on

Product Home SHALL display a Wi‑Fi status icon in the status-bar strip when the Wi‑Fi radio is enabled (`starting`, `on`, or `error`). The icon MUST be **absent** when the radio is **off**. Visual style SHALL follow phone/laptop conventions:

- **connecting** — in-progress affordance when the radio is `starting` or the connection phase is `associating` / `obtainingIp`
- **connected** — connected-style glyph when the connection phase is `connected` (MAY vary by signal strength when `signalDbm` is available)
- **on idle** — enabled-but-not-connected style when the radio is enabled and the connection is `disconnected` or `failed`

The icon MUST subscribe to existing `WifiController` radio/connection streams (or equivalent AppServices wiring) and MUST NOT block Home first paint.

#### Scenario: Hidden when Wi‑Fi off

- **WHEN** Wi‑Fi radio state is **off**
- **AND** the operator views Home
- **THEN** the Wi‑Fi status icon SHALL NOT be visible in the status-bar strip

#### Scenario: Connecting while associating

- **WHEN** Wi‑Fi radio is enabled
- **AND** connection phase is **associating** or **obtainingIp** (or radio is **starting**)
- **AND** the operator views Home
- **THEN** the Wi‑Fi status icon SHALL show a connecting / in-progress style

#### Scenario: Connected shows connected glyph

- **WHEN** Wi‑Fi connection phase is **connected**
- **AND** the operator views Home
- **THEN** the Wi‑Fi status icon SHALL show a connected style

#### Scenario: On but disconnected still shows icon

- **WHEN** Wi‑Fi radio is **on**
- **AND** connection phase is **disconnected** or **failed**
- **AND** the operator views Home
- **THEN** the Wi‑Fi status icon SHALL remain visible in an idle / not-connected style

### Requirement: Home shows Bluetooth status icon when adapter is on

Product Home SHALL display a Bluetooth status icon in the status-bar strip when the Bluetooth adapter is enabled (`starting`, `on`, or `error`). The icon MUST be **absent** when the adapter is **off**. Visual style SHALL follow phone/laptop conventions:

- **connecting** — in-progress affordance when the adapter is `starting`, or when a pairing challenge is outstanding (if the App exposes one)
- **connected** — connected-style glyph when the adapter is enabled and at least one remote device reports `connected`
- **on idle** — enabled-but-not-connected style when the adapter is enabled and no remote is connected

The icon MUST subscribe to existing `BluetoothController` adapter/device streams (or equivalent AppServices wiring) and MUST NOT block Home first paint.

#### Scenario: Hidden when Bluetooth off

- **WHEN** Bluetooth adapter state is **off**
- **AND** the operator views Home
- **THEN** the Bluetooth status icon SHALL NOT be visible in the status-bar strip

#### Scenario: Connecting while adapter starting

- **WHEN** Bluetooth adapter state is **starting**
- **AND** the operator views Home
- **THEN** the Bluetooth status icon SHALL show a connecting / in-progress style

#### Scenario: Connected peripheral shows connected glyph

- **WHEN** Bluetooth adapter is enabled
- **AND** at least one remote device is **connected**
- **AND** the operator views Home
- **THEN** the Bluetooth status icon SHALL show a connected style

#### Scenario: On with no connected device still shows icon

- **WHEN** Bluetooth adapter is **on**
- **AND** no remote device is connected
- **AND** the operator views Home
- **THEN** the Bluetooth status icon SHALL remain visible in an idle / not-connected style

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
