## ADDED Requirements

### Requirement: Abstract Bluetooth controller as discoverable local adapter

The system SHALL provide a reusable Dart `BluetoothController` abstraction for the HMI acting as a **local adapter that other devices (phones/PCs) can discover and connect to**. The API SHALL expose adapter enablement, local identity (name/address), discoverable and pairable controls, and management of **incoming** bonded/connected remotes (disconnect/remove). Linux SHALL implement this against BlueZ (D-Bus preferred; `bluetoothctl` allowed as interim). Callers MUST depend on the abstract type. **A2DP Sink** playback is provided by the BlueZ-ALSA stack outside this Dart API (no controller methods for media transport). **Central-role scanning or initiating connections to third-party peripherals is out of scope for this capability.**

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

### Requirement: No Bluetooth central scanner requirement

This capability MUST NOT require a Demo or API obligation to scan for or connect to arbitrary nearby Bluetooth accessories as a central. Optional low-level BlueZ tools on the system MUST NOT redefine the product API contract.

#### Scenario: Product API has no scan-others obligation

- **WHEN** the Bluetooth controller public API is reviewed against this spec
- **THEN** there is no required `startScan`/`connectToRemotePeripheral` product method for finding third-party devices (incoming-peer listing only)

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
