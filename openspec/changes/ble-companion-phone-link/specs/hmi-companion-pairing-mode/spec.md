## ADDED Requirements

### Requirement: Operator can start companion pairing mode on HMI

When the board advertises Bluetooth companion support, the HMI SHALL provide a pairing-mode entry that starts a timed companion BLE advertise/session via the HAL companion API. The UI MUST show session status (idle, advertising, connected, timed out, error) and MUST allow the operator to cancel/stop pairing mode early. Boards without companion support MUST NOT present a broken entry that crashes the process.

#### Scenario: Start pairing window

- **WHEN** the operator starts phone pairing mode on a companion-capable board
- **THEN** the HAL companion session starts LE advertising for the documented service set and the UI shows an active countdown or timeout indicator

#### Scenario: Stop pairing window

- **WHEN** the operator cancels pairing mode or the timeout expires
- **THEN** companion advertising for that window stops and unauthenticated provision writes are not accepted outside policy

#### Scenario: Unsupported board

- **WHEN** companion is not advertised on the board profile
- **THEN** the pairing entry is hidden or returns a structured unsupported message without crashing

### Requirement: Pairing mode shows association correlation

While pairing mode is active, the HMI SHALL display correlation material so the phone user can confirm the correct unit—at least one of: a short pairing code for the window, and/or a QR payload that includes SN (compatible with existing Mobile QR versioning where practical). The displayed SN MUST match the identity exposed over companion Device Info / `system.info`.

#### Scenario: Code or QR visible during advertise

- **WHEN** pairing mode is advertising
- **THEN** the HMI shows a pairing code and/or QR containing the device SN for phone confirmation

#### Scenario: Identity consistency

- **WHEN** a phone reads SN from companion device info during an active pairing window
- **THEN** that SN matches the SN shown on the HMI pairing screen

### Requirement: Pairing mode does not replace accessory or media planes

Starting or stopping companion pairing mode MUST NOT permanently disable the Bluetooth accessory-host or opt-in A2DP capabilities. Temporary session-policy adjustments allowed by the HAL coexistence policy MAY apply for the duration of the window and MUST revert when pairing mode ends.

#### Scenario: Pairing ends restores prior policy

- **WHEN** pairing mode stops after a successful or abandoned session
- **THEN** accessory-host availability returns to the board’s normal session policy without requiring a reboot
