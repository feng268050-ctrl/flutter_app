## ADDED Requirements

### Requirement: Device Information changes cloud environment tier via Device SN 5×-tap

Device Information SHALL NOT show a permanent Cloud Environment row. The operator SHALL open the app environment tier picker by tapping the **Device SN** value five times within five seconds (lws-ui `SecretTapTracker` parity). The picker SHALL offer at least Test and Prod, and MAY offer Dev. Choosing a tier MUST persist the selection and trigger a fresh API-origin probe / WebSocket reconnect when cloud runtime is active. OTA footer controls remain as today (unavailable/deferred) and are unchanged by this cloud/LAN change.

#### Scenario: Five taps on Device SN opens tier picker

- **WHEN** the operator taps Device SN five times within five seconds
- **THEN** the cloud environment tier picker is shown

#### Scenario: Idle between taps resets the counter

- **WHEN** more than five seconds elapse between taps on Device SN
- **THEN** the tap counter resets and five new taps are required

## MODIFIED Requirements

### Requirement: Device Information row set matches lws-ui without Camera Type or Camera Version

Device Information SHALL show CyberUI untitled cards with at least:

1. Identity: Device Model (QR), Device SN, Welding Gun SN  
2. Versions: System Version, Process Library Version (when available), Firmware Version (existing control-card / firmware Modbus value), Laser Version, Wire Feeder Version — and MAY retain HMI-only Kernel Version / Display Stack  
3. Focus: Focus Scale Reference  

Device Information MUST NOT show Camera Type or Camera Version. OTA footer controls (**Check for Updates**, **Automatically check for updates**) SHALL be present; when no OTA client is available they SHALL report an unavailable/deferred status rather than a false success. Device Model QR and registration flows SHALL share the v2 identity payload. Cloud environment tier MUST be changed via Device SN 5×-tap (not a permanent Settings row).

#### Scenario: No Camera Type on Device Information

- **WHEN** the operator opens Device Information
- **THEN** Camera Type is not listed
- **AND** Focus Scale Reference remains visible

#### Scenario: Welding Gun SN present

- **WHEN** the operator opens Device Information
- **THEN** a Welding Gun SN (or localized equivalent) row is visible with a value or `-`

#### Scenario: Check for Updates visible

- **WHEN** the operator opens Device Information
- **THEN** a Check for Updates action is visible

#### Scenario: No permanent cloud environment row

- **WHEN** the operator opens Device Information
- **THEN** there is no always-visible Cloud Environment settings row
