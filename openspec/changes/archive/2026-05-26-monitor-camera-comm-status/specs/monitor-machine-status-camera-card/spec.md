## ADDED Requirements

### Requirement: Machine Status shows Camera connectivity card

On **Monitor → Machine Status**, the status card grid SHALL include a **Camera** tile using the same visual pattern as existing machine status cards (label + disabled checkbox indicator). The checkbox **checked** state SHALL indicate camera communication is **healthy** (unified cache display is not `-`). The checkbox **unchecked** state SHALL indicate camera communication is **fault** (cache display is `-`).

#### Scenario: Camera reachable

- **WHEN** the Machine Status screen is visible
- **AND** `CameraDeviceInfoCache.getDisplay()` returns a normalized version other than `-`
- **THEN** the Camera card checkbox SHALL appear checked (healthy/on)

#### Scenario: Camera unreachable

- **WHEN** the Machine Status screen is visible
- **AND** `CameraDeviceInfoCache.getDisplay()` returns exactly `-`
- **THEN** the Camera card checkbox SHALL appear unchecked (fault/off)

#### Scenario: Cache updates while screen visible

- **WHEN** the user is on Machine Status
- **AND** a cache refresh changes display from `-` to a valid version (or the reverse)
- **THEN** the Camera card SHALL update without requiring navigation away from the tab
