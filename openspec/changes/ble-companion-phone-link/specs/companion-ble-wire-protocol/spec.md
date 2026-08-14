## ADDED Requirements

### Requirement: Companion BLE wire protocol is versioned and documented

The project SHALL maintain a normative companion BLE protocol document for phone Central ↔ appliance Peripheral that defines at least: LE advertisement filter fields, GATT service and characteristic UUIDs and properties, frame encoding for `api_ver=1`, RPC method catalog, provision payload shape, status notify codes, and structured error codes. Implementations on the appliance and on LaserCyber Mobile MUST target the same `api_ver` revision. A client that reads an unsupported major `api_ver` MUST fail closed with a structured unsupported error and MUST NOT write provision or settings.

#### Scenario: Protocol note present for api_ver 1

- **WHEN** this change is applied for v1
- **THEN** a protocol document in the change (or linked `docs/`) defines UUIDs, JSON frame fields, and method ids for identity, provision, and `system.info`

#### Scenario: Unsupported api_ver rejected

- **WHEN** a bonded phone presents or the device advertises an incompatible major `api_ver`
- **THEN** provision and mutating RPC writes are rejected with a structured unsupported error

### Requirement: Device identity readable over companion GATT

The companion peripheral SHALL expose device identity fields required for phone association, including at least serial number (SN), model, and `api_ver`. Identity reads MAY be available to a connected client under the documented security policy; mutating operations remain subject to bonding / pairing-window rules from the companion HAL change.

#### Scenario: Phone reads SN and model

- **WHEN** a phone Central is connected to an advertising companion session and reads device info per the protocol
- **THEN** the response includes SN and model sufficient for cloud bind by SN

### Requirement: Wi-Fi provision payload matches protocol catalog

The companion Wi‑Fi provision path SHALL accept the v1 provision payload defined in the protocol document (at least SSID and optional PSK with flags as documented) and SHALL apply it only through the existing `WifiController` + credential vault path. Provision status SHALL be notified to the phone using the documented status codes. Plaintext PSK MUST NOT be logged at info level.

#### Scenario: Valid provision succeeds

- **WHEN** a bonded phone writes a valid v1 provision payload and the station can associate
- **THEN** the appliance connects via `WifiController` and notifies success status to the phone

#### Scenario: Invalid provision fails structured

- **WHEN** a phone writes a malformed provision payload
- **THEN** the appliance rejects it with a documented error code and does not change Wi‑Fi credentials

### Requirement: system.info RPC returns association-ready fields

The companion device RPC allowlist SHALL include a `system.info` (or equivalent documented method id) that returns at least SN, model, system version, and `api_ver` in a JSON object suitable for the phone App. Unknown methods MUST return structured unsupported errors without mutating state.

#### Scenario: system.info success

- **WHEN** a bonded phone invokes `system.info` with a valid request frame
- **THEN** the response includes SN, model, system version, and `api_ver`

#### Scenario: Unknown method

- **WHEN** a phone invokes an undocumented method id
- **THEN** the response is a structured error and no settings or Wi‑Fi state changes
