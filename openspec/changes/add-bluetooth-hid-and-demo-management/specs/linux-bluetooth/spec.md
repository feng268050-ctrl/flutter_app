## ADDED Requirements

### Requirement: Bluetooth central discovery and outbound device management

The system SHALL allow callers to start and stop bounded discovery of nearby Bluetooth devices and to pair, trust, connect, disconnect, and remove a selected remote through the abstract `BluetoothController`. The controller SHALL expose scan state, structured operation failures, and a deduplicated device stream containing address, name when known, paired/trusted/connected state, and best-effort device type, advertised services, and signal strength when BlueZ provides them. Linux SHALL use BlueZ D-Bus as the primary discovery, control, and observation path; a repeating `bluetoothctl` polling process MUST NOT be the primary status path.

#### Scenario: Scan reports a nearby unpaired device

- **WHEN** the adapter is on, the caller starts discovery, and BlueZ discovers a nearby unpaired device
- **THEN** the controller device stream includes one entry for that device and reports scanning active until discovery is stopped or times out

#### Scenario: Pair and connect selected device

- **WHEN** the caller requests pair-and-connect for a discovered supported device and its pairing exchange succeeds
- **THEN** the device becomes paired, trusted, and connected in the controller snapshot without requiring a separate UI refresh

#### Scenario: Discovery is bounded

- **WHEN** a scan reaches its configured timeout without an explicit stop
- **THEN** BlueZ discovery is stopped and the controller reports scanning inactive while retaining known device results

#### Scenario: Outbound operation failure is non-fatal

- **WHEN** pairing or connection fails because the device is unavailable, rejects pairing, or BlueZ reports an error
- **THEN** the operation returns a structured failure and the adapter/controller remain usable for another operation

### Requirement: Bluetooth pairing challenges are handled for headless HMI use

The system SHALL provide one deterministic BlueZ `Agent1` path that supports existing incoming pairing and outbound peripheral pairing. The Bluetooth API SHALL surface pairing requests needed for confirmation, authorization, displayed passkeys, and requested PIN/passkey input, correlate each request to its device, and allow accept, reject, or cancellation as applicable. Stale or unmatched requests MUST NOT be automatically accepted.

#### Scenario: Keyboard requires displayed passkey

- **WHEN** a selected keyboard pairing flow asks the HMI to display a passkey that must be typed on the keyboard
- **THEN** the controller exposes the passkey and device identity until BlueZ completes or cancels the request

#### Scenario: Mouse uses JustWorks confirmation

- **WHEN** a selected mouse requests a JustWorks confirmation during an explicit outbound pairing operation
- **THEN** the configured product policy confirms it and the controller continues reporting the operation state

#### Scenario: Existing incoming phone pairing still works

- **WHEN** the adapter is pairable/discoverable and a phone initiates pairing
- **THEN** the same agent path handles the incoming request without requiring removal of central scanning or Bluetooth HID support

#### Scenario: Agent recovers after bluetoothd restart

- **WHEN** bluetoothd restarts while the HMI remains running
- **THEN** the pairing agent re-registers or reports a recoverable unavailable state without crashing the Flutter process

#### Scenario: Adapter toggle recovers after bluetoothd crash

- **WHEN** bluetoothd aborts (e.g. heap corruption during HOGP teardown) and the user turns the adapter off then on
- **THEN** the Linux implementation MUST tear down without blocking on dead D-Bus activation, restart `bluetooth.service`, and re-attach a fresh BlueZ client session

#### Scenario: D-Bus can activate bluetoothd without enable

- **WHEN** `org.bluez` is absent from the system bus and a client requests it
- **THEN** systemd MUST resolve `dbus-org.bluez.service` to `bluetooth.service` even though Bluetooth remains boot-deferred (not in multi-user wants)

### Requirement: Bluetooth HID devices use the Linux input path

The image SHALL include the BlueZ and kernel support required for supported Bluetooth Classic HID and BLE HOGP keyboards and mice to appear as Linux input devices. After successful connection, keyboard keys and mouse motion/buttons/wheel events SHALL flow through the standard Linux input/libinput/flutter-pi path without a custom Dart HID report decoder.

#### Scenario: Bluetooth keyboard types into Flutter

- **WHEN** a supported Bluetooth keyboard is paired and connected and the Demo keyboard text field has focus
- **THEN** printable and common editing keys typed on the keyboard appear in the field

#### Scenario: Bluetooth mouse controls Flutter

- **WHEN** a supported Bluetooth mouse is paired and connected
- **THEN** pointer motion, primary/secondary clicks, and vertical wheel input reach Flutter and the visible pointer remains usable

#### Scenario: HID disconnect removes active input

- **WHEN** a connected Bluetooth HID device is disconnected or removed
- **THEN** its Linux input node is withdrawn or becomes inactive without crashing `hmi.service`

#### Scenario: Bonded HID reconnects

- **WHEN** a trusted Bluetooth HID device that was previously paired becomes available after Bluetooth stack restore
- **THEN** BlueZ reconnects it or the controller can reconnect it without repeating pairing, subject to the peripheral's normal reconnect behavior

### Requirement: Bluetooth roles coexist on one adapter

Central discovery and Bluetooth HID support SHALL NOT disable or remove local discoverability, pairability, incoming bonded-peer management, or the opt-in A2DP Sink capability. A user-initiated scan SHALL be finite and SHALL NOT change persisted A2DP or adapter-role preferences.

#### Scenario: Scan preserves existing controls

- **WHEN** the HMI is discoverable/pairable or A2DP Sink is enabled and the user runs a peripheral scan
- **THEN** those configured roles and preferences remain enabled after the scan completes

#### Scenario: Phone and HID bonds coexist

- **WHEN** a phone is bonded for an existing incoming/A2DP use case and a keyboard or mouse is paired from the HMI
- **THEN** both bonds remain manageable on the same adapter and removing one does not remove the other

#### Scenario: Wi-Fi remains operational during bounded scan

- **WHEN** wlan0 is connected and the user starts a Bluetooth scan on the combo radio
- **THEN** discovery completes or reports a recoverable error without intentionally disabling Wi-Fi

## MODIFIED Requirements

### Requirement: Abstract Bluetooth controller as discoverable local adapter

The system SHALL provide a reusable Dart `BluetoothController` abstraction for the HMI acting both as a **local adapter that other devices can discover and connect to** and as a **central that discovers and initiates connections to supported peripherals**. The API SHALL expose adapter enablement, local identity (name/address), discoverable and pairable controls, scan state, a unified view of discovered/bonded/connected remotes, pairing challenges, and pair/connect/disconnect/remove operations. Linux SHALL implement observation and preferred control against BlueZ D-Bus; `bluetoothctl` MUST NOT remain the primary status path. Callers MUST depend on the abstract type. **A2DP Sink** playback remains provided by the BlueZ-ALSA stack outside media transport methods on this API.

#### Scenario: Adapter enable starts deferred bluetoothd

- **WHEN** the controller is asked to enable the adapter while Bluetooth is off
- **THEN** the Linux implementation starts the deferred Bluetooth stack without requiring `bluetooth.service` in `multi-user.target.wants`

#### Scenario: Discoverable allows peer discovery

- **WHEN** the adapter is on and discoverable is enabled
- **THEN** the adapter reports discoverable=true via BlueZ so a nearby phone or PC can discover the HMI

#### Scenario: Bonded or connected remotes are listed

- **WHEN** a remote has paired or connected in either direction
- **THEN** it appears in the controller device list with address, name when known, and current paired/trusted/connected state

#### Scenario: Remove unbonds a remote

- **WHEN** remove is called for a bonded remote
- **THEN** that remote is no longer listed as bonded

#### Scenario: Adapter failures degrade gracefully

- **WHEN** `hci0` fails to come up or bluetoothd is missing
- **THEN** the controller reports an error/off adapter state and MUST NOT terminate the Flutter process

## REMOVED Requirements

### Requirement: No Bluetooth central scanner requirement

**Reason**: The product now explicitly requires scanning for and initiating connections to Bluetooth keyboards, mice, and other selectable nearby devices from the Demo.

**Migration**: Replace the incoming-only controller contract with the unified central/local-adapter contract and use the new bounded discovery and outbound device-management requirements.
