## ADDED Requirements

### Requirement: Zero point offset detection toggle gates production offset alerts

When `zeroPointOffsetDetectionEnabled` in `t_advanced_settings` is false, the system MUST NOT set pending zero-point offset alerts for laser-on zero-point detect sessions and MUST NOT show the zero-point offset dialog after laser stops for those sessions.

#### Scenario: Toggle off prevents pending during laser on

- **WHEN** `zeroPointOffsetDetectionEnabled` is false
- **AND** laser is ON in eligible production weld scope
- **THEN** zero-point offset alert pending MUST NOT be set

#### Scenario: Toggle off prevents dialog after laser off

- **WHEN** `zeroPointOffsetDetectionEnabled` was false for the entire laser-on session
- **AND** laser transitions ON to OFF
- **THEN** the zero-point offset dialog MUST NOT be shown for that session

#### Scenario: Toggle on preserves existing alert behavior

- **WHEN** `zeroPointOffsetDetectionEnabled` is true
- **AND** zero-point detect finalizes with offsets outside tolerance in eligible scope
- **THEN** existing zero-point offset alert pending and post-laser-stop dialog behavior SHALL apply unchanged
