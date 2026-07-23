# startup-bundled-firmware-upgrade Specification

## Purpose

Detect APK-bundled control-card firmware on the home screen, compare HW/SW against live `DeviceStatus`, prompt the user to confirm, and apply upgrades via the legacy Modbus OTA path without `UpgradeActivity`.

## Requirements

### Requirement: Bundled firmware is checked only on the home screen

The system SHALL NOT check for bundled firmware updates during AI/process `BundledLibraryBootstrap` import, during `Application` cold-start hooks, or on screens other than the home screen (`MainActivity`).

The system SHALL run bundled firmware version evaluation only when the home screen is visible (e.g. `MainActivity` `onResume` or an equivalent home-only lifecycle hook).

When the user navigates away from the home screen, the system SHALL NOT present bundled-firmware upgrade prompts on other activities or fragments.

When the user returns to the home screen and Modbus plus `DeviceStatus` are available, the system MAY run the check again.

#### Scenario: Home screen triggers check

- **WHEN** `MainActivity` becomes visible and Modbus is available with a valid `DeviceStatus` snapshot
- **THEN** the system SHALL evaluate whether bundled firmware is newer than the control card

#### Scenario: Non-home screen does not prompt

- **WHEN** the user is on Engineer Mode, Settings, Device Monitoring, or any screen other than `MainActivity`
- **THEN** the system SHALL NOT show a bundled-firmware upgrade dialog solely due to bundled assets

#### Scenario: Cold start does not block on firmware

- **WHEN** the application process launches
- **THEN** splash or routing to the home screen SHALL NOT be blocked waiting for firmware Modbus OTA to finish

#### Scenario: Modbus unavailable on home visit skips quietly

- **WHEN** the user is on the home screen but Modbus is unavailable or `DeviceStatus` is not yet populated
- **THEN** the system SHALL NOT show a bundled-firmware upgrade dialog

### Requirement: Bundled firmware version comparison uses filename integer rules

The system SHALL discover the bundled firmware under `assets/firmware/` (exactly one `.bin` matching `LSW01H####S####.bin`) and extract hardware and software version integers using `UpgradeFileReaderUtils` filename rules.

The system SHALL compare bundled hardware version to `DeviceStatus` hardware version; if they differ, the system SHALL NOT offer upgrade and SHALL log the mismatch.

The system SHALL compare bundled software version to `DeviceStatus` software version; upgrade SHALL be offered only when bundled software version is strictly greater than the device software version.

The system SHALL NOT use SemVer helpers for firmware version ordering.

#### Scenario: Newer bundled software triggers upgrade candidate

- **WHEN** bundled file is `LSW01H1000S1013.bin` and device reports HW=1000, SW=1012
- **THEN** the system SHALL treat firmware as an upgrade candidate on the home screen

#### Scenario: Same software version skips upgrade

- **WHEN** bundled software version equals device software version and hardware versions match
- **THEN** the system SHALL NOT invoke Modbus firmware upgrade (equivalent to legacy 606 skip semantics)

#### Scenario: Hardware mismatch skips upgrade

- **WHEN** bundled hardware version does not equal device hardware version
- **THEN** the system SHALL NOT invoke Modbus firmware upgrade

### Requirement: Bundled firmware upgrade always requires user confirmation via dialog

When an upgrade candidate is detected on the home screen, the system SHALL present a user dialog that explains a control-card firmware update is available and warns to keep power connected and avoid operation during upgrade.

The system SHALL invoke `BinUtil.binFileConvert` → `ControllerUpgradeHandler.sendControllerUpgradeInfo` only after the user explicitly confirms in that dialog.

The system SHALL NOT provide automatic or silent bundled-firmware upgrade paths, including engineer-mode bypasses or build-time flags that skip the dialog.

If the user dismisses the dialog, the system SHALL NOT start Modbus firmware upgrade for that dismissal action; the system MAY show the dialog again on a subsequent home-screen visit while the upgrade candidate remains valid.

#### Scenario: User confirms starts Modbus OTA

- **WHEN** user confirms the bundled firmware dialog on the home screen
- **THEN** the system SHALL copy the asset to a readable temporary file and call the legacy firmware upgrade entrypoint

#### Scenario: User dismisses does not upgrade

- **WHEN** user dismisses the bundled firmware dialog
- **THEN** the system SHALL NOT call `sendControllerUpgradeInfo` as a result of that dismissal

#### Scenario: No silent upgrade path exists

- **WHEN** bundled firmware is newer than the control card and the home screen check runs
- **THEN** the system SHALL NOT start Modbus firmware upgrade without showing the confirmation dialog first

### Requirement: Bundled firmware reuses legacy Modbus OTA integration

The bundled firmware path SHALL reuse `BinUtil.binFileConvert` and `ControllerUpgradeHandler` without reimplementing register-level OTA protocol.

On `DeviceUpgradeEvent` success, the system SHALL persist `DeviceInfo.firmwareVersion` from the bundled bin software version using the same semantics as `UpgradeActivity` on controller upgrade success.

On emulator or environments without a real control card, the system SHALL apply the same skip/degrade behavior as the existing OTA firmware path (no blocking error that prevents normal home-screen use).

#### Scenario: Success updates DeviceInfo firmware version

- **WHEN** bundled firmware Modbus OTA reports success
- **THEN** `DeviceInfo.firmwareVersion` SHALL be updated to the bundled bin software version string

#### Scenario: Emulator skips without blocking home screen

- **WHEN** the runtime is classified as emulator and a bundled upgrade would otherwise be offered
- **THEN** the system SHALL skip firmware upgrade without presenting a blocking error on the home screen

### Requirement: Bundled firmware does not use UpgradeActivity download flow

The bundled firmware feature SHALL NOT require HTTP download, zip extraction, or navigation to `UpgradeActivity` solely to apply firmware from APK assets.

#### Scenario: Offline device upgrades firmware from APK assets on home screen

- **WHEN** the device has no network, the user is on the home screen, APK contains `assets/firmware/*.bin`, Modbus is available, and the user confirms the dialog
- **THEN** the system SHALL upgrade control-card firmware without downloading an OTA zip

### Requirement: Bundled firmware dialogs use FrostedGlassDialog

When bundled firmware upgrade is offered or in progress on the home screen, the confirmation dialog (`showBundledFirmwareUpgradeDialog`) and the blocking in-progress dialog with determinate progress (`showStatusDialog` mode 3 / `updateFirmwareUpgradeProgress`) SHALL use `FrostedGlassDialog` with appropriate custom body content. User confirmation before upgrade and power/operation warnings MUST remain unchanged.

#### Scenario: Bundled firmware confirmation on FrostedGlass

- **WHEN** a bundled firmware upgrade candidate is detected on the home screen
- **THEN** the confirmation dialog MUST use `FrostedGlassDialog` instead of legacy `createDialogWithLayout` chrome
- **AND** confirm/cancel MUST still gate `BinUtil.binFileConvert` startup

#### Scenario: Bundled firmware progress on FrostedGlass

- **WHEN** bundled firmware upgrade is in progress after user confirmation
- **THEN** the blocking progress dialog MUST use `FrostedGlassDialog` with a custom body SeekBar and status text
- **AND** progress updates via `updateFirmwareUpgradeProgress` MUST remain functional
