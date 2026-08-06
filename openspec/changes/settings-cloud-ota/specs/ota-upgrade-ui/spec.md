## MODIFIED Requirements

### Requirement: Settings check-for-updates uses cyber_ota

Whole-device OTA operator controls SHALL live on a **dedicated Settings OTA sub-page** (CyberUI `SettingsScaffold` + untitled cards), opened from Device Information — not as an inline Device Information footer. That sub-page SHALL provide **Check for Updates** and **Automatically check for updates**, invoke `cyber_ota` against the **cloud channel manifest** for the active environment tier, and when a newer package exists present an **Update Now** (and dismiss/later) gate in the spirit of lws-ui `UpgradeActivity` idle UI (version / optional notes). **Update Now** SHALL start cloud download+apply via safe-shutdown and the dedicated **upgrade progress page** (`runCloudUpdate`). Controls MUST NOT report a false success when cloud services or API origin are unavailable, MUST NOT report “up to date” when the check could not run, and MUST NOT remain permanently deferred once this capability is implemented. Auto-check MUST NOT apply an update without operator confirmation via Update Now (or equivalent confirm).

#### Scenario: Check for Updates runs manifest check

- **WHEN** the operator activates Check for Updates on the Settings OTA sub-page and cloud services are enabled with a pinned API origin and reachable channel manifest
- **THEN** the UI reflects whether an update is available based on `cyber_ota` version compare against the running HMI app version

#### Scenario: Unavailable cloud does not claim up to date

- **WHEN** the operator activates Check for Updates and no channel manifest URL can be resolved (cloud services off or API origin not pinned)
- **THEN** the UI reports that the check is unavailable
- **AND** MUST NOT claim the device is already up to date

#### Scenario: Update Now starts cloud download on upgrade progress page

- **WHEN** Check for Updates finds a newer channel manifest and the operator activates Update Now
- **THEN** the HMI safe-shuts down, navigates to the dedicated upgrade progress page, and downloads the archive from the manifest package URL before verify/extract/apply

#### Scenario: Auto-check never auto-applies

- **WHEN** Automatically check for updates is enabled and a newer manifest is found
- **THEN** the HMI may prompt or surface the available state on the OTA sub-page
- **AND** MUST NOT start partition writes until the operator confirms with Update Now (or equivalent)

### Requirement: Dedicated upgrade page unifies transfer as download progress

Whole-device OTA progress SHALL be shown on a **dedicated upgrade progress page** (full-screen route) driven by `cyber_ota` progress callbacks — not as a dialog layered on top of laser work screens. The page SHALL use **product / CyberUI design elements** consistent with Settings and other HMI surfaces (Cyber color tokens, Cyber/Hmi button vocabulary, themed progress, card or panel chrome where appropriate) rather than an unstyled Material-only layout. The **transferring** phase SHALL be presented as **download** progress for both cloud HTTP download and host `make upgrade` HTTP pull. Subsequent phases SHALL use the same page for **cloud and host HTTP** sessions: **verify**, then **extract**, then **burn** with distinct status labels for `writing rootfs`, `writing kernel`, and `writing oem` (boot backup folded into `writing kernel` at 0%). The upgrade page SHALL NOT provide laser firing or welding/job start controls. While partition writes are in progress, the operator MUST NOT be offered a control that cancels an in-flight write. The page SHALL remain until apply finishes successfully (reboot requested) or fails with an error state.

#### Scenario: Host HTTP pull appears as download progress on upgrade page

- **WHEN** `make upgrade` has triggered a device HTTP download of the OTA `tar.gz` (and `.sig`) and the on-device session is active
- **THEN** the dedicated upgrade progress page shows advancing download/transfer progress that reflects downloaded bytes
- **AND** after the package is complete, the same page advances through verify/extract/burn

#### Scenario: Cloud download uses the same upgrade page

- **WHEN** a cloud/Settings-initiated download of the OTA `tar.gz` runs on the upgrade progress page
- **THEN** the HMI shows download progress and then verify/extract/burn for the subsequent phases

#### Scenario: Upgrade page matches product chrome

- **WHEN** the dedicated upgrade progress page is visible
- **THEN** it uses CyberUI / HMI design tokens and button/progress patterns consistent with Settings and product pages
- **AND** the operator cannot start laser output or a welding/cutting/cleaning job from that page

#### Scenario: Verify failure surfaces error without claiming flash success

- **WHEN** package signature verification fails after ingress (cloud or host HTTP)
- **THEN** the upgrade page reports failure and MUST NOT claim that partitions were successfully updated

### Requirement: Safe shutdown navigates to the dedicated upgrade page

Before starting whole-device transfer or verify-and-apply (including when triggered by host `make upgrade` at download start), the HMI SHALL enter a safe state: stop any active laser/welding work session (including extinguishing laser output / ending in-progress jobs as defined by the product App), close work screens, and navigate **directly** to the **dedicated upgrade progress page**. The HMI MUST NOT use Home as an intermediate destination for this flow. Partition writes MUST NOT begin until this safe shutdown and upgrade-page navigation have completed (or the session fails closed without writing).

#### Scenario: make upgrade trigger stops work and opens upgrade page

- **WHEN** a host starts a whole-device upgrade session (before or as package download begins) while the operator is on a work screen
- **THEN** the HMI stops laser/work activity and navigates directly to the dedicated upgrade progress page
- **AND** MUST NOT begin partition writes before that page is showing the session
- **AND** MUST NOT require navigating to Home first

#### Scenario: Cloud or Settings Update Now also safe-shuts down to upgrade page

- **WHEN** the operator activates Update Now on the Settings OTA sub-page while a work session is active
- **THEN** the HMI performs the same safe shutdown and navigates directly to the dedicated upgrade progress page before download/apply proceeds
