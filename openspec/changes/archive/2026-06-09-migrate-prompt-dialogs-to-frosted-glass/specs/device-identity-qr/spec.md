## ADDED Requirements

### Requirement: Device identity QR display uses FrostedGlassDialog

When the user opens the device identity QR code dialog from Settings Device Information, the dialog SHALL use `FrostedGlassDialog` with the QR image and related content in the custom body slot. V1/V2 QR payload generation semantics MUST NOT change.

#### Scenario: QR dialog on FrostedGlass

- **WHEN** the user requests the device identity QR code from Device Information
- **THEN** the QR dialog MUST render inside `FrostedGlassDialog`
- **AND** MUST NOT use framework `AlertDialog` window chrome as the primary visual container
