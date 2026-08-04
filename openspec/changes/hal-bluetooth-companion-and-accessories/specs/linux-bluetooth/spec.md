## ADDED Requirements

### Requirement: Linux BlueZ implements companion GATT peripheral

When the board advertises Bluetooth companion support, the Linux Bluetooth stack SHALL implement the companion plane using BlueZ LE advertising and a GATT server (GattManager application or an equivalent injectable helper port). The implementation SHALL use D-Bus as the control plane consistent with existing BlueZ observation. Companion SHALL NOT require removing opt-in A2DP Sink or accessory-host central roles from the image solely for profile coexistence.

#### Scenario: Phone tools see companion advertise

- **WHEN** companion session is started on a companion-capable ynh960 (or equivalent) image
- **THEN** a BLE central scanner can observe the companion advertisement and connect to the documented GATT service set

#### Scenario: Companion does not require A2DP

- **WHEN** A2DP Sink preference is off and companion is started
- **THEN** companion advertising and GATT remain usable

### Requirement: Linux dual-role coexistence on one adapter

The Linux implementation SHALL support running companion peripheral sessions and accessory-host central operations on the same adapter under a documented session policy. Adapter-wide mutations (discovery, advertising, pair/connect) SHALL be serialized to avoid conflicting BlueZ calls. Failures in one plane MUST NOT tear down the entire Flutter process.

#### Scenario: Companion and HID central serialize cleanly

- **WHEN** companion advertising is active and the accessory host starts a bounded scan
- **THEN** the implementation either completes both roles per session policy or returns a recoverable structured error without crashing `hmi.service`

#### Scenario: Plane failure is isolated

- **WHEN** companion GATT registration fails
- **THEN** accessory-host and adapter enable/disable remain operable

### Requirement: Board spike gate for companion on combo chips

Before marking companion enabled on a combo Wi‑Fi/BT board profile (including ynh960 AIC8800), implementers SHALL record an on-device spike result covering at least: LE advertise, GATT read/write from a phone or `bluetoothctl`/`GATT` tool, and one successful Wi‑Fi provision through companion into `WifiController`. If the spike fails, the board profile MUST omit companion (or leave it disabled) rather than advertising a broken capability.

#### Scenario: Failed spike keeps capability off

- **WHEN** the companion spike on a board fails acceptance checks
- **THEN** that board’s shipped profile does not advertise companion as supported

## MODIFIED Requirements

### Requirement: Opt-in A2DP Sink for phone media (Bluetooth speaker)

The system SHALL enable `BR2_PACKAGE_BLUEZ_ALSA` in the image and expose an **opt-in** A2DP Sink control (default **off**) via the Bluetooth platform API / Demo switch. Enabling starts bluealsa + bluealsa-aplay so phones can complete a media connection and play through the onboard speaker. `bt-stack-up.sh` MUST NOT start A2DP Sink unless preference `/var/lib/bluetooth/bt-a2dp-sink` is already `1`. A2DP Source and HFP product roles remain out of scope. **Phone management (provisioning and configuration) SHALL use the companion BLE GATT plane** defined by `hal-bluetooth-companion` when that sub-capability is enabled; A2DP Sink remains media-only and MUST NOT be the carrier for Wi‑Fi credentials or settings RPC. Companion GATT and A2DP Sink MUST be allowed to coexist on the same adapter per session policy (profiles are independent).

#### Scenario: BlueZ-ALSA A2DP Sink is enabled in the fragment

- **WHEN** the active Buildroot fragment for Bluetooth is inspected after this change
- **THEN** `BR2_PACKAGE_BLUEZ_ALSA` is set and HCITOP may remain unset

#### Scenario: Stack bring-up leaves A2DP Sink off by default

- **WHEN** `bt-stack-up.sh` successfully starts `bluetooth.service` and the A2DP preference file is missing or not `1`
- **THEN** bluealsa A2DP Sink services are not started

#### Scenario: Demo / API enables A2DP Sink

- **WHEN** the adapter is on and `setA2dpSinkEnabled(true)` is called
- **THEN** A2DP Sink services start and preference is persisted as enabled

#### Scenario: Companion and A2DP are independent

- **WHEN** companion sub-capability is enabled and A2DP Sink preference is toggled
- **THEN** toggling A2DP MUST NOT remove the companion GATT application registration requirement and companion start MUST NOT require A2DP to be on

### Requirement: Bluetooth roles coexist on one adapter

Central discovery and Bluetooth HID / accessory-host support SHALL NOT disable or remove local discoverable/pairable controls, incoming bonded-peer management, opt-in A2DP Sink capability, or the companion plane when advertised. A user-initiated accessory scan SHALL be finite and SHALL NOT change persisted A2DP or companion session preferences except where documented session policy temporarily pauses advertising or discovery. Phone companion bonds and accessory bonds SHALL be independently removable.

#### Scenario: Scan preserves existing controls

- **WHEN** the HMI is discoverable/pairable or A2DP Sink is enabled and the user runs a peripheral scan
- **THEN** those configured roles and preferences remain enabled after the scan completes

#### Scenario: Phone and HID bonds coexist

- **WHEN** a phone is bonded for companion and/or A2DP use and a keyboard or mouse is paired from the HMI
- **THEN** both bonds remain manageable on the same adapter and removing one does not remove the other

#### Scenario: Wi-Fi remains operational during bounded scan

- **WHEN** wlan0 is connected and the user starts a Bluetooth scan on the combo radio
- **THEN** discovery completes or reports a recoverable error without intentionally disabling Wi‑Fi

#### Scenario: Companion bond independent of accessory bond

- **WHEN** a companion phone bond and an accessory bond both exist and the accessory is removed
- **THEN** the companion bond remains and companion RPC remains available if the phone is connected
