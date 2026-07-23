## MODIFIED Requirements

### Requirement: Zero point offset alert shows after laser stops in production weld modes

When a laser-on zero-point detect task in Quick Mode or Engineer Mode continuous welding or spot welding completes with at least one valid sample and aggregated offsets are **outside** `ZeroPointCorrectionMapper` position tolerance, the system SHALL set a pending zero-point offset alert. The alert dialog MUST be shown only after the laser transitions **ON to OFF**, not while laser is ON.

#### Scenario: Offset outside tolerance sets pending during laser on

- **WHEN** `ZeroPointDetectCoordinator` finalizes a task with valid samples and `!isWithinPositionTolerance(meanOffsetX, meanOffsetY)`
- **AND** production weld alert scope is active
- **THEN** the system SHALL record pending zero-point offset alert for that laser-on session
- **AND** MUST NOT show the dialog until laser stops

#### Scenario: Dialog content and actions on laser stop

- **WHEN** pending zero-point offset alert exists and laser transitions ON to OFF
- **AND** production weld scope is active
- **THEN** the system SHALL show a **WarnDialog-style** alarm popup matching camera communication serious alarms (alert icon, red security alert title, scrollable body)
- **AND** the body text MUST be **零点偏移中心请及时校正**
- **AND** the footer MUST show **confirm on the left** and **go to settings on the right**
- **AND** confirm MUST dismiss the dialog with the same acknowledge semantics as other alarm confirm buttons (clear pending, allow deferred queue to continue)
- **AND** go to settings MUST exit the current Quick or Engineer weld work session (disable laser enable, stop recording, finish the mode activity)
- **AND** go to settings MUST NOT clear `ZeroPointPendingCorrectionStore` so advanced settings zero-point Auto can apply the pending correction
- **AND** go to settings MUST start `DeviceSettingActivity` with `EXTRA_INITIAL_TAB_INDEX` equal to **`TAB_INDEX_ADVANCED_SETTINGS`** (advanced settings / zero-point correction entry)

#### Scenario: Within tolerance does not alert

- **WHEN** zero-point task completes within position tolerance
- **THEN** the system MUST NOT set zero-point offset alert pending
- **AND** MUST NOT show the zero-point offset dialog

#### Scenario: No valid samples does not alert

- **WHEN** zero-point task completes with zero valid samples
- **THEN** the system MUST NOT show the zero-point offset dialog

#### Scenario: No dialog during laser on

- **WHEN** zero-point offset is detected during an active laser-on session
- **THEN** the zero-point offset dialog MUST NOT be visible until laser stops
