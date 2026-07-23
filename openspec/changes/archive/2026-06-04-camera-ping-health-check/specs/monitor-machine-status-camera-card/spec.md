## MODIFIED Requirements

### Requirement: Machine Status shows Camera connectivity card

On **Monitor → Machine Status**, the status card grid SHALL include a **Camera** tile using the same visual pattern as existing machine status cards (label + disabled checkbox indicator). The checkbox **checked** state SHALL indicate camera communication is **healthy** (ping health reports reachable). The checkbox **unchecked** state SHALL indicate camera communication is **fault** (ping health reports unreachable).

#### Scenario: Camera reachable

- **WHEN** the Machine Status screen is visible
- **AND** ping health reports the camera reachable
- **THEN** the Camera card checkbox SHALL appear checked (healthy/on)

#### Scenario: Camera unreachable

- **WHEN** the Machine Status screen is visible
- **AND** ping health reports the camera unreachable
- **THEN** the Camera card checkbox SHALL appear unchecked (fault/off)

#### Scenario: Ping health updates while screen visible

- **WHEN** the user is on Machine Status
- **AND** a ping probe changes reachability from unreachable to reachable (or the reverse)
- **THEN** the Camera card SHALL update without requiring navigation away from the tab

#### Scenario: Version cache dash with healthy ping

- **WHEN** the Machine Status screen is visible
- **AND** `CameraDeviceInfoCache.getDisplay()` is `-`
- **AND** ping health reports reachable
- **THEN** the Camera card checkbox SHALL appear checked (healthy/on)
