## ADDED Requirements

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
