# production-zero-point-offset-alerts Specification

## Purpose
Production zero-point offset user alerts during live weld AI detect: alarm code H034, warn_table logging, and immediate coded-alarm presentation.
## Requirements
### Requirement: Zero point offset alert shows immediately in production weld modes

When a laser-on zero-point detect task in Quick Mode or Engineer Mode continuous welding or spot welding completes with at least one valid sample and aggregated offsets are **outside** `ZeroPointCorrectionMapper` position tolerance, the system SHALL set a zero-point offset alert and show the warn dialog **immediately** when production weld scope is active. The system MUST NOT defer the dialog until laser transitions ON to OFF.

The alert SHALL use alarm code **H034**, SHALL persist a SERIOUS row in `warn_table` when the episode starts, and SHALL use the coded-alarm passive warn pipeline (`WarnEpisodeController` + `DeviceDialogHandler` + `AutoDialogQueue`).

#### Scenario: Offset outside tolerance shows dialog immediately

- **WHEN** `ZeroPointDetectCoordinator` finalizes a task with valid samples and `!isWithinPositionTolerance(meanOffsetX, meanOffsetY)`
- **AND** production weld alert scope is active
- **AND** `zeroPointOffsetDetectionEnabled` is true
- **THEN** the system SHALL record a zero-point offset warn log row with code **H034**
- **AND** SHALL show the warn dialog immediately (including while laser is ON)
- **AND** the dialog body MUST be **零点偏移中心请及时校正** (or localized equivalent)
- **AND** the dialog title MUST use localized zero-point offset alarm title
- **AND** the footer MUST show **confirm on the left** and **go to settings on the right**
- **AND** confirm MUST dismiss with acknowledge semantics (clear pending correction store for confirm path)
- **AND** go to settings MUST exit weld work and open `DeviceSettingActivity` advanced settings tab without clearing `ZeroPointPendingCorrectionStore`

#### Scenario: H034 participates in laser interrupt

- **WHEN** H034 passive warn is shown while laser enable is active
- **AND** `keepLaserOnWhileAlarmed` is false
- **THEN** the app SHALL force laser enable off per `alarm-laser-interrupt`
- **AND** H034 is NOT exempt via dangerous-operations trio bypass (unlike A001/C002/L001)

#### Scenario: Within tolerance does not alert

- **WHEN** zero-point task completes within position tolerance
- **THEN** the system MUST NOT set zero-point offset alert pending
- **AND** MUST NOT show the zero-point offset dialog
- **AND** MUST NOT insert H034 warn log for that session

#### Scenario: No valid samples does not alert

- **WHEN** zero-point task completes with zero valid samples
- **THEN** the system MUST NOT show the zero-point offset dialog
- **AND** MUST NOT insert H034 warn log

### Requirement: Zero point offset detection toggle gates production offset alerts

When `zeroPointOffsetDetectionEnabled` in `t_advanced_settings` is false, the system MUST NOT set pending zero-point offset alerts for laser-on zero-point detect sessions and MUST NOT show the zero-point offset dialog for detections that would have occurred while the toggle was off.

When the toggle is turned OFF while an H034 episode is still active in memory, the app MAY call fault-cleared handling to dismiss the dialog and clear runtime warn cache without deleting existing `warn_table` history rows.

#### Scenario: Toggle off prevents pending during laser on

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** laser is ON in eligible production weld scope
- **THEN** zero-point offset alert pending MUST NOT be set

#### Scenario: Toggle off clears runtime episode

- **WHEN** `zeroPointOffsetDetectionEnabled` is turned OFF
- **AND** an H034 runtime warn episode is active
- **THEN** the system SHALL clear pending state and close the H034 dialog if visible
- **AND** existing H034 warn_table rows MUST remain for history

#### Scenario: Toggle on preserves immediate alert behavior

- **WHEN** `zeroPointOffsetDetectionEnabled` is true
- **AND** zero-point detect finalizes with offsets outside tolerance in eligible scope
- **THEN** immediate H034 log + dialog behavior SHALL apply

