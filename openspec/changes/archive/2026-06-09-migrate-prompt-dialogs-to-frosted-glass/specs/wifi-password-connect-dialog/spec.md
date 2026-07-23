## MODIFIED Requirements

### Requirement: Encrypted WiFi password dialog has no separate Connect control

When joining an encrypted WiFi network from the wireless list, the password entry dialog SHALL NOT present a dedicated on-screen Connect button (or equivalent primary action control outside the soft keyboard).

The password entry dialog SHALL be hosted by `FrostedGlassDialog` with the password field in a custom body view; it MUST NOT use framework `AlertDialog` window chrome as the primary visual container.

#### Scenario: No duplicate Connect button on dialog surface

- **WHEN** the password dialog is displayed for an encrypted network
- **THEN** the dialog surface MUST NOT include a separate Connect button
- **AND** the dialog MUST use a `FrostedGlassDialog` overlay shell

#### Scenario: IME Connect submits password

- **WHEN** the user presses the soft keyboard Connect action (or hardware Enter) while entering the password
- **THEN** the app MUST validate non-empty password, initiate the existing privileged connect flow on success, and dismiss the dialog
- **AND** on empty password MUST show the existing required-password feedback without connecting
