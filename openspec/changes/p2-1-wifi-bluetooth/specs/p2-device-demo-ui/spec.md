## ADDED Requirements

### Requirement: Demo exposes Wi-Fi management section

The P2/P2.1 demo home SHALL include a Wi-Fi management section that uses the abstract `WifiController`: radio toggle; connection status (state, SSID, IPv4 when known); scan + connect to visible APs; **connect to a hidden SSID** via manual SSID + passphrase; **DHCP vs static IPv4** controls for wlan0; disconnect/forget. Wi-Fi I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables radio via controller

- **WHEN** the user turns the Wi-Fi toggle on after first frame
- **THEN** the Wi-Fi controller is asked to enable the radio

#### Scenario: Hidden network connect invokes controller

- **WHEN** the user submits a hidden SSID form with passphrase
- **THEN** the Wi-Fi controller is asked to connect with hidden=true for that SSID

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Wi-Fi controller is asked to set static IPv4 configuration

### Requirement: Demo exposes HTTP proxy and network request probe

The demo home SHALL expose HTTP(S) proxy fields (enable, host, port, optional credentials) via the HTTP client abstraction and a control to **send a network request** (configurable URL) that **displays the result** (status code and truncated body, or error). Proxy/request I/O MUST NOT block first-frame paint.

#### Scenario: User runs HTTP probe and sees result

- **WHEN** the user taps the request action with a URL after first frame
- **THEN** the HTTP client controller performs the request and the demo shows status or error text from the result

#### Scenario: Proxy save invokes controller

- **WHEN** the user saves proxy settings
- **THEN** the HTTP client controller is asked to persist those settings

### Requirement: Demo exposes Bluetooth visibility and incoming peers

The demo home SHALL include a Bluetooth section for **being discovered/connected to**: adapter toggle; local name/address; discoverable and pairable controls; list of **incoming** paired/connected remotes with disconnect/remove. The demo MUST NOT present a central “scan for other Bluetooth devices” flow. Bluetooth I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables adapter via controller

- **WHEN** the user turns the Bluetooth toggle on after first frame
- **THEN** the Bluetooth controller is asked to enable the adapter

#### Scenario: Discoverable toggle invokes controller

- **WHEN** the user enables Discoverable
- **THEN** the Bluetooth controller is asked to set discoverable true

#### Scenario: Incoming remote actions invoke controller

- **WHEN** the user taps Disconnect or Remove on a listed incoming remote
- **THEN** the Bluetooth controller is asked to disconnect or remove that address
