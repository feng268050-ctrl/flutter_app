## MODIFIED Requirements

### Requirement: Device Information card set (model QR, versions, focus; no camera type)

Device Information MUST NOT show Camera Type. Device Information MUST NOT show Kernel Version or Process Library Version. Device Information SHALL expose **System Version** as a navigation row into **System Upgrade**. Manual Check for Updates SHALL live on System Upgrade (and peripheral upgrade pages). **Auto-Check for Updates** SHALL be the Device Information Versions master switch and SHALL gate Product Home auto tips plus auto-check-on-open for System / control-board / camera upgrade pages. Auto-check MUST NOT auto-apply. Check for Updates SHALL fetch public CDN `release.json` manifests and MUST NOT require cloud services enabled or a pinned Worker API origin; when the CDN is unreachable, the check outcome MUST show failed/unavailable (not a false “up to date”). They MUST NOT report a false success, and MUST NOT remain permanently deferred/unavailable once whole-device OTA is implemented on the device image. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: Check works when cloud services off

- **WHEN** cloud services are disabled and the operator activates Check for Updates on System Upgrade and the CDN manifest is reachable
- **THEN** System Upgrade runs the check against `https://cdn.lasercyber.com/{artifact}/release.json`
- **AND** MUST NOT claim the check is unavailable solely because cloud services are off
