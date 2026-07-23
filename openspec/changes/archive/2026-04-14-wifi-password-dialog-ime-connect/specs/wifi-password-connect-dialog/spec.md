## ADDED Requirements

### Requirement: Encrypted WiFi password dialog has no separate Connect control

When joining an encrypted WiFi network from the wireless list, the password entry dialog SHALL NOT present a dedicated on-screen Connect button (or equivalent primary action control outside the soft keyboard).

#### Scenario: Dialog layout omits Connect button

- **WHEN** the password dialog is displayed for an encrypted network
- **THEN** the dialog does not include a tap target whose sole purpose is submitting the password as a duplicate of the keyboard action

### Requirement: Soft keyboard primary action shows Connect

The password field SHALL configure the input method so the primary action on the soft keyboard displays the same user-facing Connect label as used for that flow today (including localized strings), not a generic label such as Done unless it is identical to that Connect string in the active locale.

#### Scenario: IME action label matches Connect string

- **WHEN** the password field is focused and the soft keyboard is shown
- **THEN** the keyboard’s primary action is labeled with the same string resource used for the former Connect control in the active locale

### Requirement: Keyboard Connect action submits password

Pressing the soft keyboard’s Connect primary action (or hardware Enter while entering the password) SHALL run the same validation and connection behavior as the removed Connect control: non-empty password required; on success initiate the existing privileged connect flow and dismiss the dialog; on empty password show the existing required-password feedback without connecting.

#### Scenario: Submit with non-empty password

- **WHEN** the user enters a non-empty password and activates the keyboard Connect action
- **THEN** the app validates input and invokes the same connect path used before this change
- **AND** the dialog closes after a successful submit consistent with prior behavior

#### Scenario: Submit with empty password

- **WHEN** the user activates the keyboard Connect action with an empty password field
- **THEN** the app does not start a connect for that submission
- **AND** the user receives the same feedback as when the empty password was previously rejected
