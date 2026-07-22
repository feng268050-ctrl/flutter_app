## ADDED Requirements

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

## MODIFIED Requirements

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
