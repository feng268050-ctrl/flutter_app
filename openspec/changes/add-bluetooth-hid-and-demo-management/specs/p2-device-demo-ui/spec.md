## MODIFIED Requirements

### Requirement: Demo exposes Bluetooth visibility, scanning, and device management

The demo home SHALL include a Bluetooth section that supports both existing local-adapter roles and outbound peripheral management: adapter toggle; local name/address; discoverable and pairable controls; opt-in A2DP Sink control; a unified list of paired/connected remotes with disconnect/remove; bounded scan/stop controls; nearby-device results; and pair/connect actions. The section SHALL display scan and per-device operation state, best-effort device type and signal strength when available, and pairing instructions or challenges required to complete keyboard/mouse pairing. Bluetooth I/O MUST NOT block first-frame paint, and failures MUST remain local to the section without crashing or disabling unrelated controls.

#### Scenario: Toggle enables adapter via controller

- **WHEN** the user turns the Bluetooth toggle on after first frame
- **THEN** the Bluetooth controller is asked to enable the adapter

#### Scenario: Discoverable toggle invokes controller

- **WHEN** the user enables Discoverable
- **THEN** the Bluetooth controller is asked to set discoverable true

#### Scenario: Scan shows nearby devices

- **WHEN** the adapter is on and the user taps Scan
- **THEN** the controller starts bounded discovery and the section updates from its scan/device streams with deduplicated nearby-device rows

#### Scenario: User pairs and connects a scan result

- **WHEN** the user selects Pair or Connect for a nearby supported device
- **THEN** the Bluetooth controller is asked to pair/connect that device and the row shows progress followed by connected state or a non-fatal error

#### Scenario: Keyboard passkey instructions are visible

- **WHEN** pairing a keyboard requires the user to type a displayed passkey on that keyboard
- **THEN** the Bluetooth section shows the device identity, passkey, and completion instructions until the request completes or is cancelled

#### Scenario: Existing remote actions invoke controller

- **WHEN** the user taps Disconnect or Remove on a listed bonded or connected remote
- **THEN** the Bluetooth controller is asked to disconnect or remove that address

#### Scenario: Existing Bluetooth roles remain controllable

- **WHEN** central scan/connect controls are present
- **THEN** the same section still exposes discoverable, pairable, incoming-peer management, and opt-in A2DP Sink controls

#### Scenario: Bluetooth failure does not block Demo

- **WHEN** scanning, pairing, or connection fails
- **THEN** the section shows an actionable error while the rest of the Demo remains painted and usable
