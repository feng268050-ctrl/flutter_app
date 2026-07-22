## ADDED Requirements

### Requirement: Home shows top-right camera link status icon

Product Home SHALL display a camera link status icon in the top-right status area (design canvas aligned with lws-ui Home chrome near the existing Wi‑Fi icon slot). The icon SHALL reflect the **product IP-camera session** UI phase (`connecting` / `connected` / `failed`) and MUST NOT block Home first paint. The glyph SHOULD be composed from icon-font layers (camera base plus connecting spinner and/or failure mark) rather than requiring new bitmap assets.

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

## MODIFIED Requirements

### Requirement: Home provides Settings entry

The Home screen SHALL provide a visible Settings affordance that navigates to the product Settings route, and a visible Monitor affordance that navigates to the product Monitor route. Home MUST NOT, in this capability, require Quick Mode, Engineer Mode, AI Vision, or metric stat cards as full product flows (display-only stubs MAY exist for Quick/Engineer). Home SHALL include the top-right camera link status icon per the camera status requirement in this capability. Other status-bar chrome (Wi‑Fi, recording, remote lock) remains optional for later slices.

#### Scenario: Settings entry navigates

- **WHEN** the user activates the Settings entry on Home
- **THEN** the app navigates to the Settings route

#### Scenario: Monitor entry navigates

- **WHEN** the user activates the Monitor entry on Home
- **THEN** the app navigates to the Monitor route

#### Scenario: Deferred home chrome absent except camera status

- **WHEN** the user views Home after this change
- **THEN** Quick Mode, Engineer Mode, AI Vision, and the four customizable stat cards are not required to be present as full product flows (display-only stubs MAY exist)
- **AND** the top-right camera link status icon SHALL be present as specified
