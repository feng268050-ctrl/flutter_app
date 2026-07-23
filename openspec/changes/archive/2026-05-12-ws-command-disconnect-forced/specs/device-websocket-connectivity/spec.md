## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Network-driven WebSocket connection lifecycle

The device SHALL initiate or refresh the WebSocket `/ws/device` connect attempt from the application's registered `ConnectivityManager.NetworkCallback` when a suitable network becomes available (including when a suitable network is already available at the time the callback is registered). The device SHALL NOT invoke a separate Application bootstrap method whose sole purpose is initiating the first WebSocket connection to `/ws/device`.

#### Scenario: Initial connect uses network callback when network already exists

- **WHEN** a suitable network is already available and the `NetworkCallback` is registered (including at cold start)
- **THEN** the connection manager MUST receive a connect attempt for `/ws/device` without any separate Application startup-only connect invocation

#### Scenario: Reconnect after network recovery

- **WHEN** network connectivity transitions from unavailable to available and forced-disconnect reconnect suppression is **not** active in this process
- **THEN** the connection manager MUST trigger a new WebSocket connect attempt

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
