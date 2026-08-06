## MODIFIED Requirements

### Requirement: Settings check-for-updates uses cyber_ota

Device Information SHALL expose **System Version** as navigation into **System Upgrade**. System Upgrade SHALL host **Check for Updates** and **Automatically check for updates**, invoke `cyber_ota` against the **cloud channel manifest** for the active environment tier, and render check outcomes **in the content card** — not as dialogs. When a newer package exists, the card SHALL present an **Update Now** (and dismiss/later) gate (version / optional notes). **Update Now** SHALL start cloud download+apply via safe-shutdown with progress on the **same** System Upgrade page (`runCloudUpdate`, no remount required). Controls MUST NOT report a false success when cloud services or API origin are unavailable, MUST NOT report “up to date” when the check could not run, and MUST NOT remain permanently deferred once this capability is implemented. Auto-check MUST NOT apply an update without operator confirmation via Update Now (or equivalent confirm); when auto-check finds a newer package it MAY open System Upgrade already in the available state.

#### Scenario: Check for Updates runs manifest check

- **WHEN** the operator activates Check for Updates on System Upgrade and cloud services are enabled with a pinned API origin and reachable channel manifest
- **THEN** the content card reflects whether an update is available based on `cyber_ota` version compare against the running HMI app version

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

### Requirement: Dedicated upgrade page unifies transfer as download progress

Whole-device OTA progress SHALL be shown on the **System Upgrade** page driven by `cyber_ota` progress callbacks — not as a dialog layered on top of laser work screens. The page SHALL use a **full-height SettingsPanel** (blur, transparency, margins) consistent with other Settings pages. The **transferring** phase SHALL be presented as **download** progress for both cloud HTTP download and host `make upgrade` HTTP pull. Subsequent phases SHALL use the same page for **cloud and host HTTP** sessions: **verify**, then **extract**, then **burn** with distinct status labels for `writing rootfs`, `writing kernel`, and `writing oem` (boot backup folded into `writing kernel` at 0%). Host `make upgrade` (and cleared-stack host/WS apply) SHALL open System Upgrade in **progress-only** mode (no check footer). The upgrade page SHALL NOT provide laser firing or welding/job start controls. While partition writes are in progress, the operator MUST NOT be offered a control that cancels an in-flight write. The page SHALL remain until apply finishes successfully (reboot requested) or fails with an error state.

#### Scenario: Host HTTP pull appears as download progress on upgrade page

- **WHEN** `make upgrade` has triggered a device HTTP download of the OTA `tar.gz` (and `.sig`) and the on-device session is active
- **THEN** System Upgrade opens in progress-only mode and shows advancing download/transfer progress that reflects downloaded bytes
- **AND** after the package is complete, the same page advances through verify/extract/burn
- **AND** the version-check card is not shown

#### Scenario: Cloud download uses the same upgrade page

- **WHEN** a cloud/Settings-initiated download of the OTA `tar.gz` runs after Update Now
- **THEN** the HMI shows download progress and then verify/extract/burn on the same System Upgrade page

#### Scenario: Upgrade page matches Settings chrome

- **WHEN** System Upgrade is visible (check or progress)
- **THEN** it uses `SettingsScaffold` / Settings card chrome consistent with other Settings pages
- **AND** the operator cannot start laser output or a welding/cutting/cleaning job from that page

#### Scenario: Verify failure surfaces error without claiming flash success

- **WHEN** package signature verification fails after ingress (cloud or host HTTP)
- **THEN** the upgrade page reports failure and MUST NOT claim that partitions were successfully updated

### Requirement: Safe shutdown navigates to the dedicated upgrade page

Before starting whole-device transfer or verify-and-apply (including when triggered by host `make upgrade` at download start), the HMI SHALL enter a safe state: stop any active laser/welding work session (including extinguishing laser output / ending in-progress jobs as defined by the product App), close work screens, and ensure the **System Upgrade** page is showing progress. When the operator is already on System Upgrade (Update Now), navigation MUST NOT remount a separate progress route unnecessarily. When started from host `make upgrade` / cleared stack, the HMI SHALL navigate **directly** to System Upgrade (progress-only) and MUST NOT use Home as an intermediate destination. Partition writes MUST NOT begin until this safe shutdown and upgrade-page presentation have completed (or the session fails closed without writing).

#### Scenario: make upgrade trigger stops work and opens upgrade page

- **WHEN** a host starts a whole-device upgrade session (before or as package download begins) while the operator is on a work screen
- **THEN** the HMI stops laser/work activity and navigates directly to System Upgrade in progress-only mode
- **AND** MUST NOT begin partition writes before that page is showing the session
- **AND** MUST NOT require navigating to Home first

#### Scenario: Cloud or Settings Update Now also safe-shuts down

- **WHEN** the operator activates Update Now on System Upgrade while a work session is active
- **THEN** the HMI performs the same safe shutdown and shows apply progress on System Upgrade before download/apply proceeds
