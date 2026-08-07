## MODIFIED Requirements

### Requirement: Device Information shows available identity and version rows

Device Information SHALL display device identity and version rows in **untitled CyberUI card groups** (no section header text; same Settings chrome vocabulary as Common Settings), in this order:

1. **Identity:** Device Model (with device QR affordance), Device SN  
2. **Versions:** System Version (navigation into System Upgrade), Camera Version, Firmware Version (control-card / firmware Modbus display, navigation into Control Board Upgrade), Laser Version, Wire Feeder Version  
3. **Storage:** used/available capacity with an iOS-style segmented bar (see Device Information storage requirement)  
4. **Accessory:** Welding Gun SN, Focus Scale Reference  

Device Model SHALL be `brand + " " + model` from HAL product identity (Vendor Storage via `ProductInfo`), with each missing part shown as `-`; if both parts are missing (computed value `- -`), the row SHALL display a single `-`. Device SN SHALL use product identity SN resolution (non-empty Vendor Storage SN, else chip/board serial). Focus Scale Reference SHALL come from App-resolved `focus_scale_ref` (`ProductInfo.get` + product default `0`) (empty after defaults still → `-` only if intentionally blanked). Camera Version SHALL use the same normalized camera software version as Camera settings (shared cache / bounded device-info read), or `-` when unavailable. Camera Type MUST NOT appear on this tab. Kernel Version and Process Library Version MUST NOT appear on this tab (they SHALL appear on System Upgrade). The tab MUST NOT show a Modbus Link row. Missing or empty values SHALL show `-`. OTA check-update controls SHALL appear per the Device Information card-set requirement (on System Upgrade, not as a Device Information footer).

#### Scenario: Device Information lists regrouped core rows

- **WHEN** the user opens the Device Information tab
- **THEN** Device Model and Device SN appear in the first card
- **AND** System Version and Camera Version appear in the versions card
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
- **THEN** a dismissible dialog SHALL show a QR encoding `SN|2|Model|SystemVersion` (v2), with `|` characters in fields replaced by `_`

#### Scenario: Focus scale from properties.ini

- **WHEN** `properties.ini` contains `focus_scale_ref=12`
- **THEN** Focus Scale Reference SHALL display `12`

#### Scenario: Missing focus scale uses App default

- **WHEN** `focus_scale_ref` is absent from `properties.ini`
- **THEN** Focus Scale Reference SHALL display `0`

#### Scenario: Camera Version on Device Information

- **WHEN** the camera device-info read returns a normalized app version
- **THEN** Device Information Camera Version SHALL display that value
- **AND** Camera Type is still not listed on Device Information

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information SHALL show CyberUI untitled cards with:

1. Identity: Device Model (QR), Device SN  
2. Versions: System Version, Camera Version, Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version  
3. Storage: iOS-style capacity bar with `{used} of {total} used` summary and HAL `SysInfo.storage` (System = GPT system partitions; Available = `/userdata` free)  
4. Accessory (last): Welding Gun SN, Focus Scale Reference  

Device Information MUST NOT show Camera Type. Device Information MUST NOT show Kernel Version or Process Library Version. Device Information SHALL expose **System Version** as a navigation row into **System Upgrade**. Check for Updates and Automatically check for updates SHALL live on System Upgrade (not as a Device Information footer). Auto-check may open System Upgrade when a newer package exists but MUST NOT auto-apply. When cloud services are disabled or the API origin is not pinned, Check for Updates MUST show an unavailable outcome on System Upgrade (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Camera Version is listed in the versions card
- **AND** Welding Gun SN and Focus Scale Reference remain visible in the last card

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`
- **AND** it appears in the last card with Focus Scale Reference

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

#### Scenario: Kernel and process library leave Device Information

- **WHEN** the operator opens Device Information
- **THEN** Kernel Version is not listed
- **AND** Process Library Version is not listed

### Requirement: System Upgrade uses CyberUI Settings chrome

System Upgrade SHALL use the shared **Settings scaffold** and a content **SettingsPanel** that fills the remaining viewport height below the status bar (same blur / transparency / margins as other Settings pages). When not in progress-only / apply mode, the card SHALL include current system version, **Kernel Version**, **Process Library Version** (value or `-`), Check for Updates, and Automatically check for updates; check outcomes and Update Now / Later SHALL render in the card (not dialogs). Apply progress SHALL use the same full-height card. Host `make upgrade` SHALL use progress-only (no check footer); progress-only mode is not required to show Kernel / Process Library rows.

#### Scenario: Upgrade scaffold matches Settings

- **WHEN** the operator opens System Upgrade from Device Information System Version
- **THEN** the top chrome is the CyberUI page status bar with back and the System Upgrade title
- **AND** the content card fills remaining height with Settings / CyberUI panel chrome

#### Scenario: Check mode shows kernel and process library versions

- **WHEN** the operator opens System Upgrade in check mode (not progress-only)
- **THEN** Kernel Version and Process Library Version rows are visible with a value string (possibly `-`)
- **AND** System Version remains visible

## ADDED Requirements

### Requirement: Device Information shows storage capacity with an iOS-style bar

Device Information SHALL include an untitled storage card after the versions card and before the accessory card. The card SHALL present:

- A capacity summary line in the form **`{used} of {total} used`** (localized; human units such as `GB` / `MB`), placed below the Storage title and above the bar
- A single horizontal rounded **segmented bar** (iOS Settings storage style): colored **System** and **User Data** segments plus a trailing **Available** segment, with a legend
- System / User Data / Available legend labels with human-readable sizes

**Accounting (HAL `SysInfo.storage`):**

- **System** SHALL be the sum of full block sizes of board system GPT partitions (default PARTNAMEs: uboot, misc, boot, boot_b, recovery, backup, rootfs_a, rootfs_b, oem, private, private1, vendor0–3), not merely active `/` filesystem used space
- **User Data** SHALL be used space on `/userdata`
- **Available** SHALL be free space on `/userdata` only

When storage data is unavailable, the card SHALL still render without crashing and SHALL show `-` or an equivalent unavailable presentation. The storage card MUST NOT offer delete/clear actions in this change.

#### Scenario: Storage bar visible after versions

- **WHEN** the operator opens Device Information and HAL reports storage totals
- **THEN** a storage card appears below the versions card and above Welding Gun SN / Focus Scale Reference
- **AND** a summary line in the `{used} of {total} used` form is visible
- **AND** a segmented System / User Data / Available bar is visible

#### Scenario: System includes oem and other GPT system partitions

- **WHEN** HAL can read GPT part-label sizes for system partitions including `oem` and both `rootfs_a` / `rootfs_b`
- **THEN** the System segment size reflects the sum of those partition block sizes (and the other default system PARTNAMEs when present)
- **AND** Available does not include free space on `/`

#### Scenario: Storage unavailable soft-fails

- **WHEN** storage totals are missing from the SysInfo snapshot
- **THEN** Device Information still paints
- **AND** the storage presentation shows unavailable (`-` or equivalent) rather than crashing
