## Purpose

Define the device WebSocket connectivity contract for endpoint selection, network-driven connect lifecycle, online readiness gating, failure classification, reconnect policy, and command acknowledgement handling. Message framing follows `device-ws-unified-envelope`. Transport-level keepalive uses the WebSocket implementation’s native ping/pong only; there is no application-level `heartbeat` / `heartbeat_ack` protocol on this channel.
## Requirements
### Requirement: Environment-aware device WebSocket endpoint selection

The device networking layer SHALL build the `/ws/device` connection URL from the **pinned API base URL** selected by `device-api-origin-selection` (in-memory, per process), including correct `ws` vs `wss` scheme selection and preservation of any path prefix on that base. Until a pinned base exists, the device MUST NOT open a `/ws/device` connection using a legacy static host as a silent substitute.

#### Scenario: Production channel uses pinned base when Workers HTTPS wins

- **WHEN** the app runs in the production release channel (`RELEASE_CHANNEL = 1`) and the pinned API base is `https://api-prod.lasercyber.workers.dev`
- **THEN** the device WebSocket connection MUST target `wss://api-prod.lasercyber.workers.dev/ws/device?sn=<device-sn>`

#### Scenario: Non-production channel uses pinned base when Workers HTTPS wins

- **WHEN** the app runs outside the production release channel (`RELEASE_CHANNEL != 1`) and the pinned API base is `https://api-test.lasercyber.workers.dev`
- **THEN** the device WebSocket connection MUST target `wss://api-test.lasercyber.workers.dev/ws/device?sn=<device-sn>`

#### Scenario: HTTP LAN base with path prefix uses cleartext WebSocket

- **WHEN** the pinned API base is `http://47.86.53.176:8080/prod`
- **THEN** the device WebSocket connection MUST target `ws://47.86.53.176:8080/prod/ws/device?sn=<device-sn>`

#### Scenario: No pin yet means no fabricated static fallback

- **WHEN** no pinned API base has been established yet in this process
- **THEN** the device MUST NOT connect to `wss://api-prod.lasercyber.workers.dev` or `wss://api-test.lasercyber.workers.dev` solely because of the release channel without a prior successful selection round

### Requirement: Network-driven WebSocket connection lifecycle

The device SHALL initiate or refresh the WebSocket `/ws/device` connect attempt from the application's registered `ConnectivityManager.NetworkCallback` when a suitable network becomes available (including when a suitable network is already available at the time the callback is registered). The WebSocket client MUST be obtained from `NetworkHttpClientProvider` with purpose `WEBSOCKET` and route policy `INTERNET_PROXY_AWARE`. The device SHALL NOT invoke a separate Application bootstrap method whose sole purpose is initiating the first WebSocket connection to `/ws/device`.

#### Scenario: Initial connect uses network callback when network already exists

- **WHEN** a suitable network is already available and the `NetworkCallback` is registered (including at cold start)
- **THEN** the connection manager MUST receive a connect attempt for `/ws/device` without any separate Application startup-only connect invocation

#### Scenario: Reconnect after network recovery

- **WHEN** network connectivity transitions from unavailable to available and forced-disconnect reconnect suppression is **not** active in this process
- **THEN** the connection manager MUST trigger a new WebSocket connect attempt

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

### Requirement: Exponential backoff reconnect strategy

The device SHALL reconnect after disconnect using exponential backoff delays starting at 1 second and doubling each failed attempt until a configured maximum delay, **except** while forced-disconnect reconnect suppression is active in the **current application process**, during which the device MUST NOT schedule or run reconnect attempts for `/ws/device`.

#### Scenario: Progressive reconnect delays

- **WHEN** repeated reconnect attempts fail and forced-disconnect reconnect suppression is **not** active in this process
- **THEN** retry delays MUST follow `1s`, `2s`, `4s`, ... until reaching the configured cap

#### Scenario: Reset backoff after successful session

- **WHEN** the WebSocket **transport successfully opens** for a new session (handshake complete, socket ready for application frames)
- **THEN** the reconnect backoff attempt counter MUST reset to initial delay

#### Scenario: No backoff reconnect while forced disconnect applies

- **WHEN** forced-disconnect reconnect suppression is active in this process following a handled `command.disconnect`
- **THEN** the device MUST NOT schedule or execute exponential-backoff reconnect timers for `/ws/device` until that process ends or suppression would otherwise become inactive per the process-scoped rule above

### Requirement: Server-initiated forced disconnect handling

When the device receives a well-formed inbound frame with `type` `command.disconnect` (per `device-ws-unified-envelope`), the device SHALL:

1. Arm **forced-disconnect reconnect suppression** for the **current application process** (in-memory; see requirement below).
2. Close or abandon the active `/ws/device` WebSocket session from the client without treating it as a generic transient error that implies immediate reconnect.
3. Present a modal user notice on the main thread with title exactly `Disconnected from Server` and body exactly `This device has been forced to disconnect from the server, reason: {reason}` where `{reason}` is the payload `reason` string when present and valid, otherwise the empty string (no placeholder token left visible in the final string).

The device SHALL NOT require user dismissal of the dialog before arming suppression or initiating socket teardown; ordering SHALL avoid starting a new automatic connect before suppression is armed.

#### Scenario: Forced disconnect arms process-scoped suppression

- **WHEN** a `command.disconnect` frame is accepted for handling
- **THEN** forced-disconnect reconnect suppression MUST become active for the current process before any automatic reconnect for `/ws/device` is scheduled

#### Scenario: Dialog title and body match product copy

- **WHEN** the UI notice is shown for a `command.disconnect` whose `payload.reason` is `admin_reset`
- **THEN** the dialog title MUST be `Disconnected from Server` and the message body MUST be `This device has been forced to disconnect from the server, reason: admin_reset`

#### Scenario: Missing reason uses empty interpolation

- **WHEN** the `payload` has no `reason` field or `reason` is not a string
- **THEN** the message body MUST equal `This device has been forced to disconnect from the server, reason: ` with no characters following the final space (empty `{reason}` segment)

### Requirement: Forced-disconnect reconnect suppression for current process

While forced-disconnect reconnect suppression is active in the **current application process**, the device MUST NOT open or schedule opening a new `/ws/device` connection for automatic lifecycle reasons, including exponential backoff timers and network-available callbacks defined elsewhere in this capability.

#### Scenario: Network recovery does not connect when suppression is active

- **WHEN** network connectivity transitions from unavailable to available and forced-disconnect reconnect suppression is active in this process
- **THEN** the connection manager MUST NOT trigger a new `/ws/device` connect attempt because of that transition alone

#### Scenario: Suppression does not survive process restart

- **WHEN** the application process exits and a **new** process starts (for example after force-stop, crash, or swipe-away depending on OEM policy)
- **THEN** forced-disconnect reconnect suppression MUST be inactive in that new process until another `command.disconnect` is handled there

### Requirement: Command acknowledgement protocol handling
The device transport SHALL support command acknowledgement message flows using the unified WebSocket JSON envelope.

#### Scenario: Command ACK response emission
- **WHEN** a command is received and processed by the device
- **THEN** the device MUST emit an ACK using the unified envelope with `type` `ack`, with command identity and status fields carried inside `payload` as required by the server contract (including logical command identity and result code)

### Requirement: Online readiness is gated by WebSocket transport open

The device SHALL consider itself **online** (able to send outbound business frames such as `device.online`, `command.stat_response`, and command-related traffic per existing rules) when the WebSocket **transport** for the active `/ws/device` session has **successfully opened**—i.e. the secure WebSocket upgrade has completed and the client may send application text frames on that socket—without requiring any prior inbound JSON text frame. When transitioning to online under this rule, the device SHALL emit the same **online telemetry and status publication** side effects that apply whenever the connection manager enters online state (replacing the prior trigger that ran after a valid `connected` frame).

#### Scenario: Transport open implies online without inbound text

- **WHEN** the WebSocket transport reports open for the active session and no inbound application frame has been processed yet
- **THEN** the device MUST be in online state for outbound purposes per this requirement

#### Scenario: Inbound connected does not gate online

- **WHEN** the server sends no `connected` frame (or sends one only as a legacy artifact)
- **THEN** the device MUST still reach online state at transport open and MUST NOT require `connected` for that transition

#### Scenario: Online telemetry when entering online from transport open

- **WHEN** the device transitions to online because the WebSocket transport has opened
- **THEN** the connection manager MUST publish online telemetry/status consistent with entering online state elsewhere in the product (no regression solely caused by removing `connected` gating)

### Requirement: Push remote snapshot immediately after transport open

When the WebSocket transport successfully opens for a session (including after a reconnect), the device SHALL attempt to send exactly one outbound `device.online` frame for that transport-open event, as defined in `device-ws-unified-envelope`. The attempt SHALL be scheduled **immediately** from the transport-open lifecycle point (no wait for inbound server text). The send SHALL NOT depend on a prior inbound `command.stat_request`.

#### Scenario: First open after connect

- **WHEN** the WebSocket transport opens for a newly established session
- **THEN** the device MUST attempt to emit `device.online` on that session with the current remote snapshot in `payload.stat`

#### Scenario: Reconnect obtains a new push

- **WHEN** the WebSocket transport opens again after a disconnect and a new session is established
- **THEN** the device MUST again attempt to emit `device.online` for that new transport-open event with the current remote snapshot in `payload.stat`

### Requirement: Outbound online and stat response include process-parameter snapshot

The device websocket layer SHALL include `processParameters` in outbound `device.online` (`payload.stat`) and `command.stat_response` (`payload.data`) messages. The value of `processParameters` in both message types MUST be sourced from the same live in-memory snapshot defined by `device-remote-snapshot`, and MUST represent a complete current parameter view at serialization time.

#### Scenario: device.online contains current full processParameters snapshot

- **WHEN** the device emits `device.online`
- **THEN** `payload.stat` MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: command.stat_response contains current full processParameters snapshot

- **WHEN** the device emits `command.stat_response`
- **THEN** the response payload MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: Consecutive parameter changes are reflected in later outbound messages

- **WHEN** one or more process-parameter updates are committed before the next outbound `device.online` or `command.stat_response`
- **THEN** the next emitted message MUST carry `processParameters` reflecting all committed updates up to that serialization point

### Requirement: Outbound processParameters JSON property names match ProcessParametersData

The JSON object serialized for the `processParameters` field in outbound `device.online` (`payload.stat`) and `command.stat_response` (`payload.data`) messages (sourced from the in-memory snapshot per `device-remote-snapshot`) SHALL use the same camelCase property names as the `ProcessParametersData` Gson/Room model after field rename. For the logical display name, material type code, and custom material label, the JSON properties SHALL be **`name`**, **`materialType`**, and **`materialName`**. The serialized object MUST NOT include legacy keys **`paramsName`**, **`materials`**, or **`materialsName`** for those values.

#### Scenario: device.online snapshot omits legacy keys

- **WHEN** the device emits `device.online` with a non-null `processParameters` object in `payload.stat`
- **THEN** the serialized `processParameters` object MUST NOT contain the keys `paramsName`, `materials`, or `materialsName`

#### Scenario: stat_response snapshot uses canonical keys

- **WHEN** the device emits `command.stat_response` with a non-null `processParameters` object in the payload
- **THEN** any present display name, material code, and custom material label in that object MUST appear under `name`, `materialType`, and `materialName` respectively

### Requirement: WebSocket reconnects after HTTP proxy settings change

When HTTP proxy settings are saved and client generation is invalidated, `DeviceWebSocketConnectionManager` MUST close any active WebSocket and call `connectOrReconnect` with reason `proxy_settings_changed`.

#### Scenario: Proxy save triggers reconnect

- **WHEN** the user saves new HTTP proxy settings
- **THEN** the WebSocket connection manager MUST attempt reconnect using the new proxy-aware client

