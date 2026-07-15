## ADDED Requirements

### Requirement: Event-driven Bluetooth status via BlueZ D-Bus

The Linux `BluetoothController` implementation SHALL observe adapter Powered / Discoverable / Pairable / Alias and incoming Device1 objects primarily via a **long-lived BlueZ D-Bus** connection (`org.bluez` ObjectManager and PropertiesChanged, or equivalent). Periodic `bluetoothctl` via `Process` on a fixed Timer MUST NOT be the primary status path. A2DP Sink runtime activity SHOULD be observed via systemd/D-Bus unit state or bluealsa interfaces when present, while the wanted preference file remains authoritative for restore.

#### Scenario: External power off updates Streams

- **WHEN** the adapter is on in the Demo and an operator runs `bluetoothctl power off` (or stops bluetoothd) outside the HMI
- **THEN** the adapter state Stream emits off/error appropriately without a Demo tap

#### Scenario: Phone disconnect updates peer list

- **WHEN** a previously listed incoming remote disconnects
- **THEN** the incoming devices Stream updates connected/bonded flags without a Demo refresh tap

#### Scenario: No primary bluetoothctl status poll

- **WHEN** the adapter remains on for more than ten seconds
- **THEN** the implementation does not rely on a repeating Timer that forks `bluetoothctl show`/`devices` each tick as the sole means of refreshing adapter/peer state

## MODIFIED Requirements

### Requirement: Abstract Bluetooth controller as discoverable local adapter

The system SHALL provide a reusable Dart `BluetoothController` abstraction for the HMI acting as a **local adapter that other devices (phones/PCs) can discover and connect to**. The API SHALL expose adapter enablement, local identity (name/address), discoverable and pairable controls, and management of **incoming** bonded/connected remotes (disconnect/remove). Linux SHALL implement this against BlueZ with **D-Bus as the primary observation and preferred control path** (`bluetoothctl` MUST NOT remain the primary status path). Callers MUST depend on the abstract type. **A2DP Sink** playback is provided by the BlueZ-ALSA stack outside media transport methods on this API. **Central-role scanning or initiating connections to third-party peripherals is out of scope for this capability.**

#### Scenario: Adapter enable starts deferred bluetoothd

- **WHEN** the controller is asked to enable the adapter while Bluetooth is off
- **THEN** the Linux implementation starts the deferred Bluetooth stack without requiring `bluetooth.service` in `multi-user.target.wants`

#### Scenario: Discoverable allows peer discovery

- **WHEN** the adapter is on and discoverable is enabled
- **THEN** the adapter reports discoverable=true (via BlueZ) so a nearby phone or PC can discover the HMI

#### Scenario: Incoming paired or connected remotes are listed

- **WHEN** a remote device has paired or connected to the HMI
- **THEN** that remote appears in the controller’s incoming/bonded/connected device list with address and name when known

#### Scenario: Remove unbonds an incoming remote

- **WHEN** remove is called for a remote that was bonded to the HMI
- **THEN** that remote is no longer listed as bonded

#### Scenario: Adapter failures degrade gracefully

- **WHEN** `hci0` fails to come up or bluetoothd is missing
- **THEN** the controller reports an error/off adapter state and MUST NOT terminate the Flutter process
