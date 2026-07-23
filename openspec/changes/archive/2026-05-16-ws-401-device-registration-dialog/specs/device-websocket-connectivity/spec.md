## MODIFIED Requirements

### Requirement: Disconnect and auth failure handling

The device SHALL classify WebSocket failures by protocol outcome, including handshake `401` and close code `4409`. When classification is SN/registration/auth configuration error (`401` / `auth_invalid_sn`), the device MUST enter `OFFLINE_AUTH_ERROR`, cancel scheduled automatic reconnect for that failure, and present a registration modal on the main thread when a suitable foreground activity exists.

The registration modal SHALL use the same visual shell pattern as the existing bind-device / WiFi reminder dialogs (blur, dark card). The title MUST be exactly `Register This Device`. The message body MUST be exactly `This device is unrecognized, please scan the QR code with LaserCyber app to register it.` The main content area MUST display the device binding QR code using the same V2 identity payload as Settings → Device Information (via `DeviceQRCodeUtils.createDeviceIdentityQrCodeV2` or equivalent). The primary actions MUST be labeled exactly `Cancel` and `Reconnect`.

While a registration modal for this flow is already showing, the device MUST NOT open another instance for subsequent `401` events. **Cancel** SHALL dismiss the dialog only. **Reconnect** SHALL dismiss the dialog and initiate a new `/ws/device` connect attempt that clears the auth-error reconnect latch so handshake may run again (user-initiated retry, not automatic backoff).

Product copy for title, body, and button labels MUST be defined in Android string resources (default English in `values` / `values-en`; Simplified Chinese in `values-zh`) so locales can diverge from the English normative strings above only through translated resources, not hard-coded literals in Java.

#### Scenario: Handshake rejected with 401

- **WHEN** WebSocket upgrade fails with HTTP `401`
- **THEN** the device MUST classify the failure as SN/registration/auth configuration error (`auth_invalid_sn`)
- **AND** the device MUST NOT schedule exponential-backoff reconnect for that failure
- **AND** when a foreground activity is available, the device MUST show the registration modal with title `Register This Device`, body `This device is unrecognized, please scan the QR code with LaserCyber app to register it.`, device identity QR code, and actions `Cancel` and `Reconnect`

#### Scenario: Close with 401

- **WHEN** the active WebSocket connection is closed with code `401`
- **THEN** the device MUST apply the same classification, reconnect suppression, and registration modal rules as for handshake HTTP `401`

#### Scenario: Reconnect retries handshake

- **WHEN** the operator taps `Reconnect` on the registration modal
- **THEN** the dialog MUST be dismissed
- **AND** the connection manager MUST allow a new connect attempt for `/ws/device` (clearing the `OFFLINE_AUTH_ERROR` + `auth_invalid_sn` latch that blocks automatic retry)

#### Scenario: Cancel does not reconnect

- **WHEN** the operator taps `Cancel` on the registration modal
- **THEN** the dialog MUST be dismissed
- **AND** the device MUST NOT start a new `/ws/device` connect attempt solely because of that tap

#### Scenario: Duplicate 401 does not stack dialogs

- **WHEN** a registration modal for `401` is already visible and another `401` occurs
- **THEN** the device MUST NOT show a second registration modal on top of the first

#### Scenario: Connection replaced with 4409

- **WHEN** the active connection is closed with code `4409`
- **THEN** the device MUST treat it as connection replacement behavior and continue lifecycle handling without fatal error classification or the registration modal
