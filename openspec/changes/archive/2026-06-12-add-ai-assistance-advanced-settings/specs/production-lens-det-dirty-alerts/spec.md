## ADDED Requirements

### Requirement: Lens contamination detection toggle gates production dirty alerts

When `lensContaminationDetectionEnabled` in `t_advanced_settings` is false, the system MUST NOT set production heavy dirty-alert pending from live-weld OpenCV stain detect and MUST NOT show the production heavy lens dirty dialog for detections that would have occurred while the toggle was off during the laser-on session.

#### Scenario: Toggle off prevents pending during laser on

- **WHEN** `lensContaminationDetectionEnabled` is false
- **AND** laser is ON in eligible production weld scope
- **THEN** production heavy dirty-alert pending MUST NOT be set from live weld stain detect

#### Scenario: Toggle off prevents dialog after laser off

- **WHEN** `lensContaminationDetectionEnabled` was false for the entire laser-on session
- **AND** laser transitions ON to OFF
- **THEN** the production heavy lens dirty dialog MUST NOT be shown for that session

#### Scenario: Toggle on preserves existing alert behavior

- **WHEN** `lensContaminationDetectionEnabled` is true
- **AND** live weld stain detect reports heavy contamination in eligible scope
- **THEN** existing production dirty-alert pending and post-laser-stop dialog behavior SHALL apply unchanged
