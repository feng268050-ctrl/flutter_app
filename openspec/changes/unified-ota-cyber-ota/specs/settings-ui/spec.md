## MODIFIED Requirements

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with at least:

1. Identity: Device Model (QR), Device SN, Welding Gun SN  
2. Versions: System Version, Process Library Version (when available), Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version — and MAY retain HMI-only Kernel Version / Display Stack  
3. Focus: Focus Scale Reference  

Device Information MUST NOT show Camera Type or Camera Version. OTA footer controls (**Check for Updates**, **Automatically check for updates**) SHALL be present and SHALL call `cyber_ota` for update checks and (after operator confirmation when an update exists) for the unified download/verify/apply flow via **safe shutdown to Home** and the **dedicated upgrade page** (burn progress). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Focus Scale Reference remains visible

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`

#### Scenario: Check for Updates visible

- **WHEN** the operator opens Device Information
- **THEN** a Check for Updates action is visible

#### Scenario: Check for Updates invokes cyber_ota

- **WHEN** the operator activates Check for Updates and OTA networking is available
- **THEN** the UI uses `cyber_ota` version compare rather than a hard-coded unavailable stub

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row
