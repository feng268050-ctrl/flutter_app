## MODIFIED Requirements

### Requirement: Settings check-for-updates uses cyber_ota

Device Information SHALL expose **System Version** as navigation into **System Upgrade**. System Upgrade SHALL host **Check for Updates** (manual), invoke `cyber_ota` against the **public CDN channel manifest** at **`https://cdn.lasercyber.com/{artifact}/release.json`** (default artifact `lws-hmi`), and render check outcomes **in the content card** using **`cyber_upgrade_ui` check-card primitives** — not as dialogs. Check for Updates MUST NOT require cloud services enabled, Worker API origin pin, or environment-tier staging/release selection. When not in progress-only / apply mode, System Upgrade SHALL also display read-only **Kernel Version** and **Process Library Version** rows (value or `-`) alongside the current System Version, so upgrade-related version detail lives on this page rather than Device Information. When a newer package exists, the card SHALL present an **Update Now** (and dismiss/later) gate (version / optional notes). **Update Now** SHALL start cloud/CDN download+apply via safe-shutdown with progress on the **same** System Upgrade page (`runCloudUpdate`, no remount required). Controls MUST NOT report a false success when the CDN manifest is unreachable, MUST NOT report “up to date” when the check could not run, and MUST NOT remain permanently deferred once this capability is implemented.

**Auto-Check for Updates** SHALL be a single master switch on Device Information (Versions group, last row)—not a checkbox on System Upgrade / control-board / camera upgrade pages. When that switch is on, Product Home tips and opening those upgrade pages MAY auto-run a version check; Auto-check MUST NOT apply an update without operator confirmation via Update Now (or equivalent confirm).

#### Scenario: Check for Updates runs manifest check

- **WHEN** the operator activates Check for Updates on System Upgrade and `https://cdn.lasercyber.com/lws-hmi/release.json` is reachable
- **THEN** the content card reflects whether an update is available based on `cyber_ota` version compare against the running HMI app version
- **AND** the check outcome is presented via `cyber_upgrade_ui` check-card UI
- **AND** the resolved manifest URL MUST NOT depend on cloud services enable or pinned Worker API origin

#### Scenario: Unreachable CDN does not claim up to date

- **WHEN** the operator activates Check for Updates and the CDN channel manifest cannot be fetched (network error or HTTP failure)
- **THEN** the System Upgrade content card reports that the check failed or is unavailable
- **AND** MUST NOT claim the device is already up to date
- **AND** MUST NOT use a dialog for that outcome

#### Scenario: Check works with cloud services disabled

- **WHEN** cloud services are disabled and the operator activates Check for Updates on System Upgrade and the CDN manifest is reachable
- **THEN** the check runs against `https://cdn.lasercyber.com/{artifact}/release.json`
- **AND** MUST NOT require enabling cloud services

#### Scenario: Update Now starts cloud download on System Upgrade

- **WHEN** Check for Updates finds a newer channel manifest and the operator activates Update Now
- **THEN** the HMI safe-shuts down and downloads the archive from the manifest package URL on the same System Upgrade page before verify/extract/apply

#### Scenario: Auto-check never auto-applies

- **WHEN** Auto-Check for Updates is enabled on Device Information and a newer manifest is found
- **THEN** the HMI may open System Upgrade with the available state (or an equivalent confirm tip)
- **AND** MUST NOT start partition writes until the operator confirms with Update Now (or equivalent)

#### Scenario: Kernel and process library versions on System Upgrade

- **WHEN** the operator opens System Upgrade in check mode from Device Information
- **THEN** Kernel Version and Process Library Version are visible on System Upgrade
- **AND** Device Information does not list those rows
