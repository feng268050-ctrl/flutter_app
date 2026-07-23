## Purpose

Define expected behavior for the encrypted WiFi password connect dialog so submission happens through the IME Connect action without a duplicate on-screen Connect button.
## Requirements
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

### Requirement: Soft keyboard primary action shows Connect

The WiFi password field SHALL configure the custom in-app IME Enter key to display the same user-facing Connect label used for that flow today (including localized strings). The system soft keyboard and `EditText.setImeActionLabel` MUST NOT be required for this behavior once the custom IME is active.

#### Scenario: Custom Enter key label matches Connect string

- **WHEN** the password field is focused and the custom IME keyboard is shown
- **THEN** the Enter key MUST be labeled with the same string resource used for the former Connect control in the active locale
- **AND** MUST use primary orange Enter styling

#### Scenario: Enter submits password

- **WHEN** the user taps Enter on the custom keyboard while entering the password
- **THEN** the app MUST validate non-empty password, initiate the existing privileged connect flow on success, and dismiss the dialog
- **AND** on empty password MUST show the existing required-password feedback without connecting

### Requirement: Keyboard Connect action submits password

Pressing the soft keyboard's Connect primary action (or hardware Enter while entering the password) SHALL run the same validation and connection behavior as the removed Connect control: non-empty password required; on success initiate the existing privileged connect flow and dismiss the dialog; on empty password show the existing required-password feedback without connecting.

#### Scenario: Submit with non-empty password

- **WHEN** the user enters a non-empty password and activates the keyboard Connect action
- **THEN** the app validates input and invokes the same connect path used before this change
- **AND** the dialog closes after a successful submit consistent with prior behavior

#### Scenario: Submit with empty password

- **WHEN** the user activates the keyboard Connect action with an empty password field
- **THEN** the app does not start a connect for that submission
- **AND** the user receives the same feedback as when the empty password was previously rejected

### Requirement: WiFi password dialog uses Mono when password is visible

The WiFi password connect dialog SHALL apply JetBrains Mono to the password `EditText` when characters are visible, and SHALL NOT require Mono for masked bullet display.

#### Scenario: WiFi password hidden

- **WHEN** the WiFi password field is masked
- **THEN** the field MAY use system password masking without JetBrains Mono

#### Scenario: WiFi password revealed

- **WHEN** the user toggles password visibility to show plaintext
- **THEN** the EditText MUST use JetBrains Mono for character distinction

### Requirement: Join dialog Advanced IP settings default to DHCP

The Advanced IP Settings section in the Wi‑Fi join dialog SHALL default to DHCP. STATIC fields MUST be hidden or disabled until the user selects STATIC mode.

#### Scenario: DHCP is default on join

- **WHEN** the join dialog opens for a network without a saved STATIC profile
- **THEN** IP mode MUST default to DHCP

