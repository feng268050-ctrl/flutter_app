## ADDED Requirements

### Requirement: Firmware may be delivered via bundled APK assets or OTA zip

Control-card firmware updates SHALL be deliverable through either:

1. the existing `lws-app` OTA zip download and `UpgradeActivity` extraction path, or
2. the home-screen bundled-firmware feature that reads firmware from `assets/firmware/` after user confirmation on `MainActivity`.

Both paths SHALL converge on the same legacy Modbus firmware upgrade implementation (`BinUtil` / `ControllerUpgradeHandler`). Neither path SHALL be removed by the introduction of the other.

When both an OTA session and a bundled-firmware upgrade could run concurrently, the implementation SHALL serialize controller firmware upgrade so only one Modbus OTA session is active at a time.

#### Scenario: OTA zip firmware path remains valid

- **WHEN** the user completes an online `lws-app` OTA that includes a `.bin` in the extracted zip
- **THEN** firmware SHALL still be applied through the existing OTA firmware path unchanged

#### Scenario: Bundled firmware does not disable OTA

- **WHEN** the APK contains bundled firmware assets
- **THEN** the OTA manifest check and zip download flow SHALL remain available for App and firmware updates delivered via `lws-app`

#### Scenario: Concurrent upgrade attempts are serialized

- **WHEN** bundled firmware upgrade is in progress
- **THEN** a new OTA firmware upgrade SHALL NOT start a second concurrent Modbus OTA session
