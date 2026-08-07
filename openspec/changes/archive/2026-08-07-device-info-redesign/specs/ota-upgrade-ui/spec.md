## MODIFIED Requirements

### Requirement: Settings check-for-updates uses cyber_ota

Device Information SHALL expose **System Version** as navigation into **System Upgrade**. System Upgrade SHALL host **Check for Updates** and **Automatically check for updates**, invoke `cyber_ota` against the **cloud channel manifest** for the active environment tier, and render check outcomes **in the content card** using **`cyber_upgrade_ui` check-card primitives** — not as dialogs. When not in progress-only / apply mode, System Upgrade SHALL also display read-only **Kernel Version** and **Process Library Version** rows (value or `-`) alongside the current System Version, so upgrade-related version detail lives on this page rather than Device Information. When a newer package exists, the card SHALL present an **Update Now** (and dismiss/later) gate (version / optional notes). **Update Now** SHALL start cloud download+apply via safe-shutdown with progress on the **same** System Upgrade page (`runCloudUpdate`, no remount required). Controls MUST NOT report a false success when cloud services or API origin are unavailable, MUST NOT report “up to date” when the check could not run, and MUST NOT remain permanently deferred once this capability is implemented. Auto-check MUST NOT apply an update without operator confirmation via Update Now (or equivalent confirm); when auto-check finds a newer package it MAY open System Upgrade already in the available state.

#### Scenario: Check for Updates runs manifest check

- **WHEN** the operator activates Check for Updates on System Upgrade and cloud services are enabled with a pinned API origin and reachable channel manifest
- **THEN** the content card reflects whether an update is available based on `cyber_ota` version compare against the running HMI app version
- **AND** the check outcome is presented via `cyber_upgrade_ui` check-card UI

#### Scenario: Unavailable cloud does not claim up to date

- **WHEN** the operator activates Check for Updates and no channel manifest URL can be resolved (cloud services off or API origin not pinned)
- **THEN** the System Upgrade content card reports that the check is unavailable
- **AND** MUST NOT claim the device is already up to date
- **AND** MUST NOT use a dialog for that outcome

#### Scenario: Update Now starts cloud download on System Upgrade

- **WHEN** Check for Updates finds a newer channel manifest and the operator activates Update Now
- **THEN** the HMI safe-shuts down and downloads the archive from the manifest package URL on the same System Upgrade page before verify/extract/apply

#### Scenario: Auto-check never auto-applies

- **WHEN** Automatically check for updates is enabled and a newer manifest is found
- **THEN** the HMI may open System Upgrade with the available state
- **AND** MUST NOT start partition writes until the operator confirms with Update Now (or equivalent)

#### Scenario: Kernel and process library versions on System Upgrade

- **WHEN** the operator opens System Upgrade in check mode from Device Information
- **THEN** Kernel Version and Process Library Version are visible on System Upgrade
- **AND** Device Information does not list those rows
