## ADDED Requirements

### Requirement: C-series communication alarm codes

Alarm codes with prefix **C** SHALL denote **communication (通讯)** faults. **`C001`** is reserved by the laser module fault table (`warn_code` resource: temperature-control board ↔ refrigeration system communication) and SHALL NOT be reused for the industrial camera. **Industrial camera HTTP communication** faults SHALL use alarm code **`C002`**.

#### Scenario: Camera fault uses C002 not C001

- **WHEN** the app raises a camera communication alarm
- **THEN** the warn table and popup SHALL use alarm code **C002**
- **AND** the app MUST NOT use **C001** for camera communication

### Requirement: Camera communication fault raises operator alarm

When camera HTTP communication is abnormal (unified cache display is `-` after a completed refresh attempt), the app SHALL record an exception/warn log entry and present a **popup warning** to the operator using the same alarm dialog pipeline as gun and feeder communication faults. When communication recovers (cache display is no longer `-`), the app SHALL clear the camera communication alarm.

#### Scenario: Fault detected after failed deviceinfo

- **WHEN** `CameraDeviceInfoCache` holds display `-` following a completed refresh that did not obtain a valid `appVersion`
- **THEN** the app SHALL add or retain a warn table entry with alarm code **C002** (camera communication)
- **AND** the operator SHALL see a popup with the localized camera communication alarm title and guidance text

#### Scenario: Recovery clears alarm

- **WHEN** a subsequent refresh stores a normalized version other than `-`
- **THEN** the app SHALL remove the C002 warn entry
- **AND** the camera communication popup SHALL be dismissed or not re-shown for that fault cycle

#### Scenario: Exception log on fault transition

- **WHEN** camera communication transitions from healthy to fault on production hardware
- **THEN** the app SHALL write an exception/diagnostic log line including alarm code **C002** (consistent with other comm alarm logging)

#### Scenario: No duplicate popups while fault persists

- **WHEN** camera communication remains faulted across multiple 1 Hz refresh cycles
- **THEN** the app SHALL NOT spam repeated popups for the same active C002 fault (same debounce/once-per-fault semantics as existing comm alarms)
