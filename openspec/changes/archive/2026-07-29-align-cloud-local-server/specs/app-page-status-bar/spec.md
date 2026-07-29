## MODIFIED Requirements

### Requirement: This product composes the current three status icons into the strip

For this product’s current Home / Monitor / Settings adoption, the App SHALL build `CyberHomeStatusBar` `items` as **Wi‑Fi · Bluetooth · camera** (left to right), mapping live radio/adapter/session state into CyberUI icon phases. Wi‑Fi and Bluetooth MUST be hidden when radio/adapter is off. Camera glyph phases SHALL reflect the product IP-camera session UI status and MUST remain resolvable when Home is not mounted. When remote lock is active, the App SHALL also include a remote-lock indicator in the status chrome (adjacent to the connectivity cluster or as an additional item) so operators can see lock state without opening Settings. This composition is a **product policy** for the current icon set; it MUST NOT imply that `CyberHomeStatusBar` is limited to a fixed icon count forever.

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

#### Scenario: Remote lock indicator when locked

- **WHEN** remote lock is active
- **AND** the operator views Home or page status chrome that includes connectivity icons
- **THEN** a remote-lock indicator SHALL be visible
