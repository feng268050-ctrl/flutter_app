# laser-enable-emulator-preflight Specification

## Purpose
TBD - created by archiving change optimize-laser-enable. Update Purpose after archive.
## Requirements
### Requirement: Laser-enable preflight SHALL skip key-switch check on emulator

When the user initiates **laser enable** in **quick mode** or **engineer mode**, the preflight path (`EngineerModeCheck.checkWorkStatus` / `EngineerModeCheck.enableLaser`) SHALL evaluate key-switch state **only on production hardware**. On an Android emulator (runtime classified by `AndroidEmulatorUtils.isLikelyEmulator()` or equivalent mock Modbus path), a key-switch-off condition MUST NOT block laser enable and MUST NOT show `check_key_error_text`.

All other preflight checks (device status present, E-stop, camera communication alarm C002, shielding gas alarm A001, lens heavy contamination L001 laser-enable guard, and subsequent `DeviceDialogHandler.quickCheckDeviceStatus`) SHALL remain unchanged on emulator and production hardware except where dangerous-operations toggles bypass an active C002, A001, or L001 guard as specified in `advanced-settings-dangerous-operations`.

#### Scenario: Emulator with key switch off allows laser enable

- **WHEN** the app runs on an emulator
- **AND** `DeviceStatus.isKeySwitchOn()` is false
- **AND** all other preflight checks pass
- **THEN** `EngineerModeCheck.enableLaser` MUST return true
- **AND** MUST NOT display the key-switch error dialog

#### Scenario: Production hardware with key switch off blocks laser enable

- **WHEN** the app runs on production hardware (non-emulator)
- **AND** `DeviceStatus.isKeySwitchOn()` is false
- **THEN** `EngineerModeCheck.enableLaser` MUST return false
- **AND** MUST display `check_key_error_text`

#### Scenario: Production hardware with key switch on unchanged

- **WHEN** the app runs on production hardware
- **AND** `DeviceStatus.isKeySwitchOn()` is true
- **AND** all other preflight checks pass
- **THEN** laser-enable preflight behavior MUST match pre-change behavior for unrelated alarms

#### Scenario: Active gas alarm blocks laser enable unless bypassed

- **WHEN** the app runs on production hardware or emulator
- **AND** shielding gas alarm A001 is active
- **AND** `allowWorkAfterGasAlarm` is false
- **THEN** `EngineerModeCheck.enableLaser` MUST return false
- **AND** the operator MUST see the A001 warn dialog on that attempt

#### Scenario: Active camera fault blocks laser enable unless bypassed

- **WHEN** the app runs on production hardware or emulator
- **AND** camera communication fault C002 is active
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** `EngineerModeCheck.enableLaser` MUST return false
- **AND** the operator MUST see the C002 warn dialog on that attempt

