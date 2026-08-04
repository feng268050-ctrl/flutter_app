## ADDED Requirements

### Requirement: Shipped BlueZ meets security pin floor

The Linux Bluetooth stack SHALL run BlueZ userspace at the version required by `buildroot-bluez-security` (minimum **5.87**). Adapter bring-up, discoverable local role, central HID/HOGP, and opt-in A2DP Sink behaviors defined elsewhere in this capability MUST continue to work on that pin.

#### Scenario: bluetoothd version after upgrade

- **WHEN** Bluetooth stack is started on a post-change image
- **THEN** `bluetoothd -v` reports ≥ 5.87 and D-Bus `org.bluez` remains usable by the Linux Bluetooth controller

### Requirement: Security hardening must not remove required roles

Optional Bluetooth security hardening (OBEX disable, pairing policy tweaks, reconnect UUID trim) MUST NOT remove or permanently disable: (1) discoverable/pairable local adapter controls, (2) Classic HID and BLE HOGP input after successful connect, or (3) opt-in A2DP Sink via BlueZ-ALSA when the user enables it.

#### Scenario: A2DP Sink still opt-in after hardening

- **WHEN** hardening is applied and the user enables A2DP Sink preference
- **THEN** bluealsa A2DP Sink services can still start per existing A2DP Sink requirements

#### Scenario: HID input path retained

- **WHEN** hardening is applied and a supported HID/HOGP device is paired and connected
- **THEN** key/mouse events still appear on the Linux input path
