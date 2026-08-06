## MODIFIED Requirements

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with at least:

1. Identity: Device Model (QR), Device SN, Welding Gun SN  
2. Versions: System Version, Process Library Version (when available), Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version — and MAY retain HMI-only Kernel Version / Display Stack  
3. Focus: Focus Scale Reference  

Device Information MUST NOT show Camera Type or Camera Version. Device Information SHALL expose **System Version** as a navigation row into **System Upgrade**. Check for Updates and Automatically check for updates SHALL live on System Upgrade (not as a Device Information footer). Auto-check may open System Upgrade when a newer package exists but MUST NOT auto-apply. When cloud services are disabled or the API origin is not pinned, Check for Updates MUST show an unavailable outcome on System Upgrade (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Focus Scale Reference remains visible

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`

#### Scenario: System Version opens System Upgrade

- **WHEN** the operator activates the System Version row on Device Information
- **THEN** System Upgrade is shown (shared Settings scaffold)

#### Scenario: Check unavailable when cloud off

- **WHEN** cloud services are disabled and the operator activates Check for Updates on System Upgrade
- **THEN** System Upgrade indicates the check is unavailable in the content card
- **AND** MUST NOT claim the system is up to date

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row

## ADDED Requirements

### Requirement: System Upgrade uses CyberUI Settings chrome

System Upgrade SHALL use the shared **Settings scaffold** and a content **SettingsPanel** that fills the remaining viewport height below the status bar (same blur / transparency / margins as other Settings pages). When not in progress-only / apply mode, the card SHALL include current system version, Check for Updates, and Automatically check for updates; check outcomes and Update Now / Later SHALL render in the card (not dialogs). Apply progress SHALL use the same full-height card. Host `make upgrade` SHALL use progress-only (no check footer).

#### Scenario: Upgrade scaffold matches Settings

- **WHEN** the operator opens System Upgrade from Device Information System Version
- **THEN** the top chrome is the CyberUI page status bar with back and the System Upgrade title
- **AND** the content card fills remaining height with Settings / CyberUI panel chrome
