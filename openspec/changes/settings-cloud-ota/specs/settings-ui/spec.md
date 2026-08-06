## MODIFIED Requirements

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with at least:

1. Identity: Device Model (QR), Device SN, Welding Gun SN  
2. Versions: System Version, Process Library Version (when available), Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version — and MAY retain HMI-only Kernel Version / Display Stack  
3. Focus: Focus Scale Reference  

Device Information MUST NOT show Camera Type or Camera Version. Device Information SHALL expose a **navigation entry** to the **Settings OTA sub-page** (Check for Updates / system update — same Settings scaffold pattern as Cloud services / Wi‑Fi). It MUST NOT host the full OTA footer (Check for Updates button + Automatically check for updates checkbox) inline once the sub-page exists. The OTA sub-page SHALL call `cyber_ota` against the tier-selected cloud channel manifest and, after **Update Now**, run the unified **cloud** download/verify/apply flow via **safe shutdown directly to the dedicated upgrade progress page**. When cloud services are disabled or the API origin is not pinned, Check for Updates on the OTA sub-page MUST show an unavailable outcome (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Focus Scale Reference remains visible

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`

#### Scenario: OTA opens Settings sub-page

- **WHEN** the operator activates the Device Information OTA / system-update entry
- **THEN** the Settings OTA sub-page is shown (shared Settings scaffold / CyberUI page status bar)

#### Scenario: OTA sub-page hosts check and auto-check

- **WHEN** the operator is on the Settings OTA sub-page
- **THEN** Check for Updates and Automatically check for updates are available there
- **AND** Device Information does not duplicate those footer controls inline

#### Scenario: Check unavailable when cloud off

- **WHEN** cloud services are disabled and the operator activates Check for Updates on the OTA sub-page
- **THEN** the UI indicates the check is unavailable
- **AND** MUST NOT claim the system is up to date

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row

## ADDED Requirements

### Requirement: Settings OTA sub-page uses CyberUI Settings chrome

The Settings OTA sub-page SHALL use the shared **Settings scaffold** (CyberUI page status bar: back, title, status icons, clock) and untitled CyberUI / Settings card groups consistent with other Settings sub-pages (e.g. Cloud services). Body content SHALL include at least current system version, Check for Updates, and Automatically check for updates; when an update is available it SHALL show version (and optional notes) with Update Now / Later before starting apply.

#### Scenario: Sub-page scaffold matches Settings

- **WHEN** the operator opens the Settings OTA sub-page from Device Information
- **THEN** the top chrome is the CyberUI page status bar with back and the OTA page title
- **AND** body groups use Settings / CyberUI card chrome without operator-visible section header titles
