## ADDED Requirements

### Requirement: Home may overlay boot self-check after first paint

Product Home SHALL remain the launcher and first-paint target. When boot self-check is enabled and not yet completed in-process, Home MAY present the self-check dialog as an overlay after the first frame without delaying Home’s initial paint on Modbus or camera I/O.

#### Scenario: First paint does not wait on self-check Modbus

- **WHEN** the App navigates to Home as the initial route
- **THEN** Home chrome SHALL paint without waiting for the self-check Modbus snapshot to complete
- **AND** the self-check dialog, if shown, SHALL appear as a subsequent overlay
