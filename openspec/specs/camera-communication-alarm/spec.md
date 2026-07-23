## Purpose

Raise and clear operator-facing camera communication alarms when ping health reports the camera unreachable, using C-series alarm code **C002** and the same popup pipeline as other comm faults.
## Requirements
### Requirement: C-series communication alarm codes

Alarm codes with prefix **C** SHALL denote **communication (通讯)** faults. **`C001`** is reserved by the laser module fault table (`warn_code` resource: temperature-control board ↔ refrigeration system communication) and SHALL NOT be reused for the industrial camera. **Industrial camera communication** faults SHALL use alarm code **`C002`**.

#### Scenario: Camera fault uses C002 not C001

- **WHEN** the app raises a camera communication alarm
- **THEN** the warn table and popup SHALL use alarm code **C002**
- **AND** the app MUST NOT use **C001** for camera communication

### Requirement: Camera communication fault raises operator alarm

When camera communication is abnormal (ping health reports unreachable after a completed probe), the app SHALL record an exception/warn log entry and present a **popup warning** to the operator using the same alarm dialog pipeline as gun and feeder communication faults. When communication recovers (ping health reports reachable), the app SHALL clear the camera communication alarm. C002 popups and warn-table updates from the periodic monitor MUST NOT occur while **boot self-check** is active (see `boot-self-check` capability).

C002 warn dialog severity MUST follow `warn-dialog-severity`: `WARN_TYPE` when `allowWorkAfterCameraAlarm` is false (default), `INFO_TYPE` when true. Only `WARN_TYPE` C002 dialogs MUST play warn alarm sound when displayed.

#### Scenario: Fault detected after failed ping

- **WHEN** the camera ping health module reports unreachable following a completed probe
- **AND** boot self-check is not active
- **AND** `allowWorkAfterCameraAlarm` is false
- **THEN** the app SHALL add or retain a warn table entry with alarm code **C002** (camera communication)
- **AND** the operator SHALL see a popup with the localized camera communication alarm title and guidance text
- **AND** the popup MUST use `WARN_TYPE`
- **AND** the popup SHALL play warn alarm sound

#### Scenario: Fault with camera bypass shows info dialog

- **WHEN** the camera ping health module reports unreachable
- **AND** `allowWorkAfterCameraAlarm` is true
- **THEN** any C002 popup shown MUST use `INFO_TYPE`
- **AND** MUST NOT play warn alarm sound

#### Scenario: Recovery clears alarm

- **WHEN** a subsequent ping probe reports the camera reachable
- **THEN** the app SHALL remove the C002 warn entry
- **AND** the camera communication popup SHALL be dismissed or not re-shown for that fault cycle

#### Scenario: Exception log on fault transition

- **WHEN** camera communication transitions from healthy to fault on production hardware
- **AND** boot self-check is not active
- **THEN** the app SHALL write an exception/diagnostic log line including alarm code **C002** (consistent with other comm alarm logging)

#### Scenario: No duplicate popups while fault persists

- **WHEN** camera communication remains faulted across multiple 1 Hz ping cycles
- **THEN** the app SHALL NOT spam repeated popups for the same active C002 fault (same debounce/once-per-fault semantics as existing comm alarms)

#### Scenario: Version unavailable does not raise comm fault when ping is healthy

- **WHEN** `CameraDeviceInfoCache.getDisplay()` is `-` because version fetch has not succeeded
- **AND** ping health reports reachable
- **THEN** the app SHALL NOT raise or retain C002 solely due to missing camera version

#### Scenario: No C002 popup during boot self-check

- **WHEN** boot self-check is active
- **AND** a ping probe would otherwise report unreachable
- **THEN** the app MUST NOT add C002 warn entries or show camera communication popups
- **AND** the self-check dialog SHALL be the sole operator-facing camera health feedback for that window

