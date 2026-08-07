## Why

Device Information currently mixes identity, accessory SN, OS/kernel/process-library versions, and focus calibration in a layout that does not match operator mental models: upgrade-related detail belongs with System Upgrade, Camera Version is only buried under Camera settings, and there is no on-device storage overview despite HAL already exposing mount free/total. Redesigning the tab clarifies “about this device,” surfaces camera firmware next to other versions, and adds an iOS-style storage bar for capacity awareness.

## What Changes

- Reorder Device Information into untitled CyberUI card groups:
  1. **Identity** — Device Model (QR), Device SN only (Welding Gun SN leaves this group)
  2. **Versions** — System Version (nav → System Upgrade), **Camera Version**, Control Board Version (nav), Laser Version, Wire Feeder Version
  3. **Storage** — used/free capacity with an **iOS-style segmented bar** (and readable used/available text)
  4. **Accessory / calibration (last group)** — Welding Gun SN, Focus Scale Reference
- **Remove** Kernel Version and Process Library Version from Device Information; show them on the **System Upgrade** page (check mode), alongside current System Version / OTA controls
- **Add** Camera Version on Device Information (same normalized value as Camera settings / cloud cache); Camera Type remains Camera-settings-only
- **BREAKING** (spec): Device Information previously MUST NOT show Camera Version; this change requires it. Kernel / Process Library rows leave Device Information

## Capabilities

### New Capabilities

- (none) — storage presentation and group reorder stay under existing Settings / OTA UI capabilities; HAL `SysInfo.storage` already exists

### Modified Capabilities

- `settings-ui`: Device Information group membership and order; Camera Version allowed/required on Device Info; storage group with bar chart; Welding Gun SN + Focus Scale Reference as last group; drop Kernel / Process Library from this tab
- `ota-upgrade-ui`: System Upgrade check-mode content includes Kernel Version and Process Library Version (in addition to System Version + check/auto-check chrome)

## Impact

- App UI: `device_information_tab.dart`, `system_upgrade_page.dart`, shared Settings chrome widgets (new storage bar if none exists), l10n ARBs for storage labels / units
- Data: reuse `SysInfo.watch` → `StorageInfo` (`/` and `/userdata` per board profile); reuse `CameraDeviceInfoCache` (or equivalent) for Camera Version; existing kernel / process-lib sources move display-only to System Upgrade
- Specs: update `settings-ui` and `ota-upgrade-ui` requirements that currently forbid Camera Version on Device Info and place Kernel / Process Library / Focus / Gun SN in the old three-card layout
- No HAL API redesign expected; no OTA apply-path changes
