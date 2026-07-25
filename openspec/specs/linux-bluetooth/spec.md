# linux-bluetooth Specification

## Purpose

Linux Bluetooth for the HMI as both a **discoverable local adapter** (phones/PCs find and connect to it, optional A2DP Sink via BlueZ-ALSA) and a **central** that discovers, pairs, and connects supported peripherals (Bluetooth Classic HID / BLE HOGP keyboards and mice) through BlueZ D-Bus and the Linux input path.

**Deferred acceptance (regression):** Classic HID SDP spike and full device-matrix acceptance (keyboard typing, mouse pointer/click/scroll, reconnect after BT toggle/reboot) remain open — see archived change `add-bluetooth-hid-and-demo-management` notes § Deferred regression (tasks 1.2 / 7.3). BLE HOGP (QM002) field work is recorded there; do not treat Classic HID as product-complete until that regression passes.

## Requirements

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

The image SHALL include the BlueZ and kernel support required for supported Bluetooth Classic HID and BLE HOGP keyboards and mice to appear as Linux input devices. After successful connection, keyboard keys and mouse motion/buttons/wheel events SHALL flow through the standard Linux input/libinput/eLinux HMI path without a custom Dart HID report decoder.

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
- **THEN** BlueZ Policy reconnects it when Trusted (user Disconnect clears Trusted so Policy does not immediately re-attach; Connect restores Trusted), and when Connected the HAL attaches HOGP/HID input if Linux evdev is missing or ServicesResolved is false — including a brief Untrust→Disconnect→Trust→Connect refresh for sticky LE. `inputReady` requires Connected and ServicesResolved and matching evdev. A ~15s health tick auto-ensures Connected-but-not-ready remotes (45s cooldown); Demo Reconnect is fallback only (no image `bt-hid-heal` service)

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

### Requirement: Opt-in A2DP Sink for phone media (Bluetooth speaker)

The system SHALL enable `BR2_PACKAGE_BLUEZ_ALSA` in the image and expose an **opt-in** A2DP Sink control (default **off**) via the Bluetooth platform API / Demo switch. Enabling starts bluealsa + bluealsa-aplay so phones can complete a media connection and play through the onboard speaker. `bt-stack-up.sh` MUST NOT start A2DP Sink unless preference `/var/lib/bluetooth/bt-a2dp-sink` is already `1`. A2DP Source and HFP product roles remain out of scope. This MUST NOT preclude a later BLE GATT (or SPP) provisioning service on the same adapter.

#### Scenario: BlueZ-ALSA A2DP Sink is enabled in the fragment

- **WHEN** the active Buildroot fragment for Bluetooth is inspected after this change
- **THEN** `BR2_PACKAGE_BLUEZ_ALSA` is set and HCITOP may remain unset

#### Scenario: Stack bring-up leaves A2DP Sink off by default

- **WHEN** `bt-stack-up.sh` successfully starts `bluetooth.service` and the A2DP preference file is missing or not `1`
- **THEN** bluealsa A2DP Sink services are not started

#### Scenario: Demo / API enables A2DP Sink

- **WHEN** the adapter is on and `setA2dpSinkEnabled(true)` is called
- **THEN** A2DP Sink services start and preference is persisted as enabled

#### Scenario: Future provisioning coexistence

- **WHEN** a later phase adds BLE GATT (or Classic SPP) provisioning
- **THEN** that work MUST NOT require removing A2DP Sink solely due to profile coexistence (profiles are independent)
