## ADDED Requirements

### Requirement: Product Home may offer bundled camera firmware updates

In addition to control-board bundled firmware, the system SHALL evaluate bundled camera program firmware when Product Home is visible, the camera HTTP path is reachable, and ship assets include a valid camera ZIP.

Camera Home tips SHALL use `cyber_upgrade_ui` dialog primitives and App camera-upgrade l10n. Confirm SHALL start the camera CGI flash + reboot + wait-online path (not Modbus).

Home auto-detect for camera SHALL share the once-per-HMI-process tip budget family with control-board: after a camera tip is shown or a no-candidate check completes for camera in that process, returning to Home MUST NOT re-prompt camera until the next process start (unless implemented as a separate once flag that still prevents spam).

When both control-board and camera candidates are present, the system SHALL present the control-board tip first and SHALL NOT show the camera tip until the control-board tip flow has settled (confirmed, dismissed, or no CB candidate).

#### Scenario: Home offers camera when newer ZIP bundled

- **WHEN** Product Home is visible, camera deviceinfo is available, bundled camera ZIP is newer than live `appVersion`, and no control-board tip is pending
- **THEN** the system SHALL show a camera firmware update confirm tip

#### Scenario: Control-board tip takes priority

- **WHEN** both control-board and camera upgrade candidates exist on Product Home
- **THEN** the system SHALL present the control-board bundled-firmware tip before any camera tip

#### Scenario: Camera dismiss does not flash

- **WHEN** the operator dismisses the camera Home tip
- **THEN** the system SHALL NOT start CGI camera upgrade from that dismissal
