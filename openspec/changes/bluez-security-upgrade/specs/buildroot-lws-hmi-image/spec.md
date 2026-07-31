## ADDED Requirements

### Requirement: Rootfs ships overlay-pinned BlueZ

The lws_hmi rootfs SHALL include BlueZ userspace (`bluetoothd` and related tools enabled by `lws_hmi_bt.config`) built from the overlay-pinned `bluez5_utils` version required by `buildroot-bluez-security`, not the vendor SDK default of BlueZ 5.77.

#### Scenario: rootfs bluetoothd version is pinned

- **WHEN** a product rootfs built after this change is inspected on device or in `target/`
- **THEN** `bluetoothd -v` reports the overlay pin (≥ 5.87), not `5.77`
