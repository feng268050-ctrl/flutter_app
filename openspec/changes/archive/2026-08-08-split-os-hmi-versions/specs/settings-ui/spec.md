## MODIFIED Requirements

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **untitled CyberUI card groups** (no section header text; same Settings chrome vocabulary as Common Settings), in this order:

1. **Identity:** Device Model (with device QR affordance), Device SN  
2. **Versions:** **OS Version** (navigation into System Upgrade), **HMI Version** (navigation into HMI Upgrade), Camera Version, Firmware Version (control-card / firmware Modbus display, navigation into Control Board Upgrade), Laser Version, Wire Feeder Version, **Auto-Check for Updates** (master switch, last row)  
3. **Storage:** used/available capacity with an iOS-style segmented bar (see Device Information storage requirement)  
4. **Accessory:** Welding Gun SN, Focus Scale Reference  

Device Model SHALL be `brand + " " + model` from HAL product identity (Vendor Storage via `ProductInfo`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty Vendor Storage SN, else chip/board serial). Focus Scale Reference SHALL come from App-resolved `focus_scale_ref` (`ProductInfo.get` + product default `0`) (empty after defaults still → `-` only if intentionally blanked). Camera Version SHALL use the same normalized camera software version as Camera settings (shared cache / bounded device-info read), or `-` when unavailable. Camera Type MUST NOT appear on this tab. Kernel Version and Process Library Version MUST NOT appear on this tab (Kernel on System Upgrade; Process Library on HMI Upgrade). The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. Manual **Check for Updates** SHALL live on System Upgrade / HMI Upgrade / peripheral upgrade pages; the **Auto-Check for Updates** master switch SHALL live on Device Information Versions (not as checkboxes on those upgrade pages).

#### Scenario: Device Information lists regrouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model and Device SN appear in the first card
- **AND** OS Version and HMI Version appear in the versions card
- **AND** Auto-Check for Updates is the last row of the versions card
- **AND** Kernel Version and Process Library Version are not shown on Device Information
- **AND** a storage card with a capacity bar is visible after the versions card
- **AND** Welding Gun SN and Focus Scale Reference appear together in the last card
- **AND** Camera Type is not shown
- **AND** Modbus Link is not shown

#### Scenario: Empty brand and model show single dash

- **WHEN** product brand and model are both empty
- **THEN** the Device Model row SHALL display `-` (not `- -`)

#### Scenario: Combined brand and model

- **WHEN** product brand is `Innohi` and model is `YNH960`
- **THEN** the Device Model row SHALL display `Innohi YNH960`

#### Scenario: Device QR opens identity payload

- **WHEN** the user activates the device QR control on the Device Model row
- **THEN** a dismissible dialog SHALL show a QR encoding the documented v2 identity payload (including version fields as specified by device-registration / remote snapshot after the OS/HMI split), with `|` characters in fields replaced by `_`

#### Scenario: Focus scale from properties.ini

- **WHEN** `properties.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`

#### Scenario: Missing focus scale uses App default

- **WHEN** `focus_scale_ref` is absent from `properties.ini`
- **THEN** Focus Scale Reference SHALL display the App default (`0` unless product docs say otherwise)

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with:

1. Identity: Device Model (QR), Device SN  
2. Versions: **OS Version**, **HMI Version**, Camera Version, Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version, **Auto-Check for Updates** (switch, last)  
3. Storage: iOS-style capacity bar with `{used} of {total} used` summary and HAL `SysInfo.storage` (System = GPT system partitions; Available = `/userdata` free)  
4. Accessory (last): Welding Gun SN, Focus Scale Reference  

Device Information MUST NOT show Camera Type. Device Information MUST NOT show Kernel Version or Process Library Version. Device Information SHALL expose **OS Version** as a navigation row into **System Upgrade** and **HMI Version** as a navigation row into **HMI Upgrade**. Manual Check for Updates SHALL live on System Upgrade, HMI Upgrade, and peripheral upgrade pages. **Auto-Check for Updates** SHALL be the Device Information Versions master switch and SHALL gate Product Home auto tips plus auto-check-on-open for System / HMI / control-board / camera upgrade pages. Auto-check MUST NOT auto-apply. Check for Updates SHALL fetch public CDN `release.json` manifests and MUST NOT require cloud services enabled or a pinned Worker API origin; when the CDN is unreachable, the check outcome MUST show failed/unavailable (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Camera Version is listed in the versions card
- **AND** Welding Gun SN and Focus Scale Reference remain visible in the last card

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`
- **AND** it appears in the last card with Focus Scale Reference

#### Scenario: OS Version opens System Upgrade

- **WHEN** the operator activates the OS Version row on Device Information
- **THEN** System Upgrade is shown (shared Settings scaffold)

#### Scenario: HMI Version opens HMI Upgrade

- **WHEN** the operator activates the HMI Version row on Device Information
- **THEN** HMI Upgrade is shown (shared Settings scaffold)

#### Scenario: Check works when cloud services off

- **WHEN** cloud services are disabled and the operator activates Check for Updates on System Upgrade and the CDN manifest is reachable
- **THEN** System Upgrade runs the check against `https://cdn.lasercyber.com/{artifact}/release.json`
- **AND** MUST NOT claim the check is unavailable solely because cloud services are off

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row

#### Scenario: Kernel and process library leave Device Information

- **WHEN** the operator opens Device Information
- **THEN** Kernel Version is not listed
- **AND** Process Library Version is not listed

### Requirement: System Upgrade uses CyberUI Settings chrome

System Upgrade SHALL use the shared **Settings scaffold** and a content **SettingsPanel** that fills the remaining viewport height below the status bar (same blur / transparency / margins as other Settings pages). When not in progress-only / apply mode, the card SHALL include current **OS Version**, **Kernel Version** (value or `-`), and **Check for Updates**; check outcomes and Update Now / Later SHALL render in the card (not dialogs). **Process Library Version MUST NOT appear on System Upgrade**. The Auto-Check for Updates switch MUST NOT appear on System Upgrade (it lives on Device Information). Apply progress SHALL use the same full-height card. Host `make upgrade` SHALL use progress-only (no check footer); progress-only mode is not required to show Kernel rows.

#### Scenario: Upgrade scaffold matches Settings

- **WHEN** the operator opens System Upgrade from Device Information OS Version
- **THEN** the top chrome is the CyberUI page status bar with back and the System Upgrade title
- **AND** the content card fills remaining height with Settings / CyberUI panel chrome

#### Scenario: Check mode shows kernel but not process library

- **WHEN** the operator opens System Upgrade in check mode (not progress-only)
- **THEN** Kernel Version is visible with a value string (possibly `-`)
- **AND** OS Version remains visible
- **AND** Process Library Version is not listed
