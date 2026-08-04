## ADDED Requirements

### Requirement: HAL exposes a phone companion plane

The portable HAL SHALL provide an abstract phone-facing **companion** API (name MAY be `BleCompanionServer` or equivalent) distinct from the adapter/HID controller. The companion API SHALL support starting and stopping a BLE peripheral session (LE advertising + GATT application), reporting session/connection state, and exposing provision and device-RPC entrypoints. Callers MUST depend on the abstract type. Boards that do not advertise the companion sub-capability MUST fail construction or operations with a structured unsupported error and MUST NOT crash the HMI process.

#### Scenario: Companion start when capability present

- **WHEN** the board profile advertises Bluetooth companion support and the caller starts the companion session
- **THEN** the Linux backend enables LE advertising for the companion service set and registers the GATT application without requiring A2DP Sink to be on

#### Scenario: Companion unsupported on board

- **WHEN** the board profile omits companion support and the caller requests start
- **THEN** the API returns a structured unsupported failure and does not leave a partial advertise state

#### Scenario: Companion stop clears advertise

- **WHEN** a running companion session is stopped
- **THEN** LE advertising for that session stops and open companion writes are rejected until started again

### Requirement: Companion Wi-Fi provision uses existing Wi-Fi HAL

The companion plane SHALL accept a Wi‑Fi provision request (at least SSID and optional PSK, with hidden/requires-PSK flags as needed) and SHALL apply it by calling the existing portable `WifiController` connect/provision path so operator secrets persist only through the existing Wi‑Fi credential vault / Secrets mechanism. The companion plane MUST NOT write plaintext PSKs into a new preference file and MUST NOT log PSK material at info level. Provision progress and terminal success/failure SHALL be observable to the phone via companion status notify (or equivalent).

#### Scenario: Provision connects station

- **WHEN** a bonded companion client writes a valid provision payload and Wi‑Fi radio can associate
- **THEN** `WifiController` performs connect for that SSID and companion status reports success after association or a structured failure if association fails

#### Scenario: Provision does not create parallel secret store

- **WHEN** provision succeeds
- **THEN** the PSK is handled only through the existing vault/Secrets path used by normal Settings Wi‑Fi connect

### Requirement: Companion device RPC for configuration

The companion plane SHALL expose a versioned device RPC (request/response with correlation id) for allowlisted configuration and info methods. v1 SHALL include at least device identity/info and get/set for an allowlisted settings key set that delegates to existing HAL ports (no duplicate persist trees). Methods outside the allowlist MUST return a structured unsupported or forbidden error. The RPC contract SHALL be documented so a future LAN or cloud carrier can implement the same methods without a second settings model.

#### Scenario: Allowlisted setting set

- **WHEN** a companion client invokes an allowlisted settings set method with a valid payload
- **THEN** the corresponding HAL port applies the change and the RPC response indicates success

#### Scenario: Unknown method rejected

- **WHEN** a companion client invokes an unknown method id
- **THEN** the response is a structured error and no HAL persist state changes

### Requirement: Companion session security baseline

Writes that provision Wi‑Fi or change settings SHALL require an authenticated companion link per product policy (at least BlueZ bonding/encryption unless an explicit timed open-pairing window is active). The HAL SHALL support limiting the open-pairing/advertise window with a timeout after which advertising stops or returns to a non-accepting policy. Multiple bonded phones MAY exist at the Bluetooth layer; the companion API SHALL document whether concurrent RPC sessions are single-active or multi-active (v1 MAY be single-active).

#### Scenario: Advertise window times out

- **WHEN** companion pairing/advertise mode is started with a timeout and no phone completes bonding before expiry
- **THEN** advertising for that window stops and unauthenticated provision writes are not accepted

#### Scenario: Unbonded write rejected outside open window

- **WHEN** companion is running without an open pairing window and an unbonded client attempts provision or settings write
- **THEN** the write is rejected and Wi‑Fi/settings state is unchanged
