## ADDED Requirements

### Requirement: HAL exposes an accessory host plane

The portable HAL SHALL provide an abstract **accessory host** API for the appliance acting as Bluetooth central toward accessories. The API SHALL support registering typed accessory profiles, bounded discovery filtered by the active profiles, and connect/disconnect/remove (or equivalent) of accessories. It SHALL expose a unified accessory list with at least address, display name when known, profile id, and connection state. Callers MUST depend on the abstract type. Boards without accessory-host support MUST fail with structured unsupported errors.

#### Scenario: Host lists connected accessory

- **WHEN** an accessory of a registered profile is connected
- **THEN** it appears in the accessory host list with its profile id and connected state

#### Scenario: Accessory host unsupported

- **WHEN** accessory-host is not advertised on the board profile and the caller starts discovery
- **THEN** the API returns structured unsupported and does not start BlueZ discovery solely for that call

### Requirement: HID and HOGP are the v1 accessory profile

The accessory host SHALL ship a **HID accessory profile** that preserves existing product behavior for supported Bluetooth Classic HID and BLE HOGP keyboards and mice: pair/connect through BlueZ, input via the Linux input/evdev path without a custom Dart HID report decoder, and reconnect/heal semantics consistent with `linux-bluetooth`. Demo and Settings callers MAY continue to use adapter-level pair APIs during migration, but the long-term portable path for “accessories” SHALL be the host + HID profile.

#### Scenario: Keyboard through HID profile

- **WHEN** the HID profile is registered and a supported Bluetooth keyboard is paired and connected via the accessory host
- **THEN** key events appear on the Linux input path as with the pre-change HID controller behavior

#### Scenario: Mouse through HID profile

- **WHEN** the HID profile is registered and a supported Bluetooth mouse is paired and connected via the accessory host
- **THEN** pointer and button/wheel events remain usable in the HMI

### Requirement: Accessory profiles are extensible

The accessory host SHALL allow additional profiles to be registered with at least: stable profile id, discovery matching hints (service UUIDs and/or device class hints), and connect/disconnect lifecycle hooks. A future helmet (or similar) profile MUST be addable without modifying companion GATT code. This change MUST NOT require implementing helmet sensor codecs; a profile MAY no-op domain streams until a later change.

#### Scenario: Second profile registration

- **WHEN** a test or future profile with a distinct id is registered alongside HID
- **THEN** discovery/connect dispatch can target that profile id without removing the HID profile

#### Scenario: Unknown profile connect rejected

- **WHEN** the caller requests connect for a device that matches no registered profile
- **THEN** the host returns a structured failure and does not claim the device as a managed accessory

### Requirement: Accessory host coexists with companion and media

Enabling accessory-host discovery or connected accessories SHALL NOT permanently disable companion capability, local discoverable/pairable controls, or opt-in A2DP Sink preferences. Session policy MAY temporarily pause or bound discovery while companion pairing windows run, but MUST restore accessory-host availability afterward per policy.

#### Scenario: HID remains after companion session

- **WHEN** a keyboard accessory is connected and a companion advertise/session is started then stopped
- **THEN** the keyboard bond/connection remains manageable and input remains available unless the accessory explicitly disconnected

#### Scenario: Bounded accessory scan preserves A2DP preference

- **WHEN** A2DP Sink preference is enabled and the host runs a bounded accessory scan
- **THEN** the A2DP preference remains enabled after the scan completes
