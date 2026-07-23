## ADDED Requirements

### Requirement: Zero point line failure uses DETECT_FAILED with line_not_found

When `DetectTargetMode` is Line and no qualifying horizontal bright band is found, zero_point SHALL return `ok=false`, `code=-3` (`DETECT_FAILED`), and `reason=line_not_found`.

#### Scenario: Line not found reason token

- **WHEN** line mode runs but band selection fails
- **THEN** `code` MUST be `-3`
- **AND** `reason` MUST be `line_not_found`
