## MODIFIED Requirements

### Requirement: Encrypted WiFi password dialog has no separate Connect control

When joining a WiFi network from the wireless list, the join dialog SHALL NOT present a dedicated on-screen Connect button (or equivalent primary action control outside the soft keyboard). The join dialog SHALL be hosted by `FrostedGlassDialog` with a custom body view; it MUST NOT use framework `AlertDialog` window chrome as the primary visual container.

For **encrypted** networks the body MUST include a password field. For **open** networks the password section MUST be hidden. The dialog MUST include an **Advanced** section exposing **IP Settings** with DHCP/STATIC mode and STATIC fields (IP, mask/prefix, gateway, DNS1, optional DNS2) so users can configure static IPv4 before connect.

#### Scenario: No duplicate Connect button on dialog surface

- **WHEN** the join dialog is displayed for any network
- **THEN** the dialog surface MUST NOT include a separate Connect button
- **AND** the dialog MUST use a `FrostedGlassDialog` overlay shell

#### Scenario: Open network shows IP settings without password

- **WHEN** the join dialog is displayed for an open (non-encrypted) network
- **THEN** the password field MUST be hidden
- **AND** the Advanced IP Settings section MUST remain available

#### Scenario: IME Connect submits join request

- **WHEN** the user presses the soft keyboard Connect action (or hardware Enter) on an encrypted network with non-empty password
- **THEN** the app MUST validate input including IP settings, invoke `WifiConnectionCoordinator.connect`, and dismiss the dialog on success
- **AND** on empty password MUST show the existing required-password feedback without connecting

## ADDED Requirements

### Requirement: Join dialog Advanced IP settings default to DHCP

The Advanced IP Settings section in the Wi‑Fi join dialog SHALL default to DHCP. STATIC fields MUST be hidden or disabled until the user selects STATIC mode.

#### Scenario: DHCP is default on join

- **WHEN** the join dialog opens for a network without a saved STATIC profile
- **THEN** IP mode MUST default to DHCP
