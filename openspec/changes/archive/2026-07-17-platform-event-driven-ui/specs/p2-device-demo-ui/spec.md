## ADDED Requirements

### Requirement: Demo live sections follow OS event-driven controllers

For Demo surfaces that display **live OS state** (Ethernet, Wi‑Fi, Bluetooth, LAN SSH debug, USB keyboard presence, and—when Streams exist—backlight/volume/timezone), the Demo SHALL update solely from abstract controller Streams (or equivalent notifications). Demo-local `Timer` status polls that shell out for those surfaces MUST NOT remain the primary update path. Modbus telemetry, LED modes, orientation apply, and on-demand HTTP probe results are excluded from this requirement.

#### Scenario: No Demo-local Wi-Fi/Ethernet status Timer

- **WHEN** Ethernet and Wi‑Fi Demo sections are mounted
- **THEN** they do not run their own Timer that invokes `ip`/`wpa_cli` for status; they listen to controller Streams

### Requirement: Demo exposes LAN SSH debug with live state

The demo home SHALL include a LAN SSH debug control that uses `SshDebugController`: enable/disable on-demand LAN SSH, and SHALL reflect enabled state from a live Stream when the unit is started or stopped outside the Demo.

#### Scenario: Toggle enables LAN SSH via controller

- **WHEN** the user turns LAN SSH debug on after first frame
- **THEN** the SSH debug controller is asked to enable LAN SSH

#### Scenario: External LAN SSH stop visible in Demo

- **WHEN** LAN SSH is on in the Demo and an operator runs `systemctl stop ssh-debug-lan.service`
- **THEN** the Demo shows disabled without a further Demo tap

### Requirement: Demo exposes USB keyboard presence from event monitor

The demo home SHALL include a USB keyboard section that shows HID keyboard presence from an event-driven monitor (udev) Stream and a text field for key input. Presence MUST NOT rely on a Demo-local Timer scanning `/dev/input` as the primary path.

#### Scenario: Unplug updates presence in Demo

- **WHEN** a USB HID keyboard is unplugged while the section is mounted
- **THEN** the Demo presence line updates without a further Demo tap

## MODIFIED Requirements

### Requirement: Demo exposes Ethernet management section above Wi-Fi

The P2/P2.1 demo home SHALL include an Ethernet (RJ45 / eth0) management section that uses the abstract `EthernetController`: interface enable toggle; link/carrier status (and IPv4 when known); **DHCP vs static IPv4** controls for eth0. The Ethernet section SHALL appear **above** the Wi-Fi management section. The section SHALL update from controller Streams when link/address changes occur outside the Demo (e.g. `ip link`, unplug, DHCP). Ethernet I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables interface via controller

- **WHEN** the user turns the Ethernet toggle on after first frame
- **THEN** the Ethernet controller is asked to enable the interface

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Ethernet controller is asked to set static IPv4 configuration

#### Scenario: DHCP mode invokes controller

- **WHEN** the user selects DHCP mode and applies
- **THEN** the Ethernet controller is asked to set DHCP IPv4 configuration

#### Scenario: Ethernet appears before Wi-Fi

- **WHEN** the user scrolls the demo home after network sections are ready
- **THEN** the Ethernet management section is laid out above the Wi-Fi management section

#### Scenario: External eth0 change visible in Demo

- **WHEN** eth0 is up in the Demo and an operator brings the link down via shell or unplugs the cable
- **THEN** the Demo Ethernet status updates without a further Demo tap

### Requirement: Demo exposes Wi-Fi management section

The P2/P2.1 demo home SHALL include a Wi-Fi management section that uses the abstract `WifiController`: radio toggle; connection status (state, SSID, IPv4 when known); scan + connect to visible APs; **connect to a hidden SSID** via manual SSID + passphrase; **DHCP vs static IPv4** controls for wlan0; disconnect/forget. The section SHALL update connection status from Streams when the stack changes outside the Demo (e.g. `wpa_cli disconnect`). Wi-Fi I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables radio via controller

- **WHEN** the user turns the Wi-Fi toggle on after first frame
- **THEN** the Wi-Fi controller is asked to enable the radio

#### Scenario: Hidden network connect invokes controller

- **WHEN** the user submits a hidden SSID form with passphrase
- **THEN** the Wi-Fi controller is asked to connect with hidden=true for that SSID

#### Scenario: Static IPv4 form invokes controller

- **WHEN** the user selects static mode and applies a valid address/prefix
- **THEN** the Wi-Fi controller is asked to set static IPv4 configuration

#### Scenario: External stack change visible in Demo

- **WHEN** Wi-Fi radio is on in the Demo and an operator disconnects or reconnects via `wpa_cli` on wlan0
- **THEN** the Demo connection status updates without a further Demo tap

### Requirement: Demo exposes Bluetooth visibility and incoming peers

The demo home SHALL include a Bluetooth section for **being discovered/connected to**: adapter toggle; local name/address; discoverable and pairable controls; list of **incoming** paired/connected remotes with disconnect/remove. The demo MUST NOT present a central “scan for other Bluetooth devices” flow. The section SHALL update from controller Streams when adapter/peer state changes outside the Demo. Bluetooth I/O MUST NOT block first-frame paint.

#### Scenario: Toggle enables adapter via controller

- **WHEN** the user turns the Bluetooth toggle on after first frame
- **THEN** the Bluetooth controller is asked to enable the adapter

#### Scenario: Discoverable toggle invokes controller

- **WHEN** the user enables Discoverable
- **THEN** the Bluetooth controller is asked to set discoverable true

#### Scenario: Incoming remote actions invoke controller

- **WHEN** the user taps Disconnect or Remove on a listed incoming remote
- **THEN** the Bluetooth controller is asked to disconnect or remove that address

#### Scenario: External BT change visible in Demo

- **WHEN** Bluetooth is on in the Demo and an operator powers off the adapter via `bluetoothctl` or a phone disconnects
- **THEN** the Demo adapter and/or peer list updates without a further Demo tap
