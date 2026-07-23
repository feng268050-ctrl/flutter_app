## ADDED Requirements

### Requirement: Laser-enable preflight SHALL skip key-switch check on emulator

When the user initiates **laser enable** in **quick mode** or **engineer mode**, the preflight path (`EngineerModeCheck.checkWorkStatus` / `EngineerModeCheck.enableLaser`) SHALL evaluate key-switch state **only on production hardware**. On an Android emulator (runtime classified by `AndroidEmulatorUtils.isLikelyEmulator()` or equivalent mock Modbus path), a key-switch-off condition MUST NOT block laser enable and MUST NOT show `check_key_error_text`.

All other preflight checks (device status present, E-stop, shielding gas alarm, and subsequent `DeviceDialogHandler.quickCheckDeviceStatus`) SHALL remain unchanged on emulator and production hardware.

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
- **THEN** laser-enable preflight behavior MUST match pre-change behavior
