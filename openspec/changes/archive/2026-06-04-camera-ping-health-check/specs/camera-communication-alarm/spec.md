## MODIFIED Requirements

### Requirement: Camera communication fault raises operator alarm

When camera communication is abnormal (ping health reports unreachable after a completed probe), the app SHALL record an exception/warn log entry and present a **popup warning** to the operator using the same alarm dialog pipeline as gun and feeder communication faults. When communication recovers (ping health reports reachable), the app SHALL clear the camera communication alarm.

#### Scenario: Fault detected after failed ping

- **WHEN** the camera ping health module reports unreachable following a completed probe
- **THEN** the app SHALL add or retain a warn table entry with alarm code **C002** (camera communication)
- **AND** the operator SHALL see a popup with the localized camera communication alarm title and guidance text

#### Scenario: Recovery clears alarm

- **WHEN** a subsequent ping probe reports the camera reachable
- **THEN** the app SHALL remove the C002 warn entry
- **AND** the camera communication popup SHALL be dismissed or not re-shown for that fault cycle

#### Scenario: Exception log on fault transition

- **WHEN** camera communication transitions from healthy to fault on production hardware
- **THEN** the app SHALL write an exception/diagnostic log line including alarm code **C002** (consistent with other comm alarm logging)

#### Scenario: No duplicate popups while fault persists

- **WHEN** camera communication remains faulted across multiple 1 Hz ping cycles
- **THEN** the app SHALL NOT spam repeated popups for the same active C002 fault (same debounce/once-per-fault semantics as existing comm alarms)

#### Scenario: Version unavailable does not raise comm fault when ping is healthy

- **WHEN** `CameraDeviceInfoCache.getDisplay()` is `-` because version fetch has not succeeded
- **AND** ping health reports reachable
- **THEN** the app SHALL NOT raise or retain C002 solely due to missing camera version
