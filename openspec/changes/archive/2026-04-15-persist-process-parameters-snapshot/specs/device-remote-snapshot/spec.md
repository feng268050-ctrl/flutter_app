## ADDED Requirements

### Requirement: Real-time process-parameter snapshot is maintained in memory
The app SHALL maintain a complete in-memory `processParameters` snapshot that reflects the latest process-parameter state for both Fast Mode and Engineer Mode. Every accepted process-parameter mutation in either mode MUST update this shared snapshot immediately, and the snapshot representation MUST remain structurally complete for downstream serialization.

#### Scenario: Fast Mode update refreshes shared snapshot
- **WHEN** Fast Mode applies a process-parameter change
- **THEN** the shared in-memory `processParameters` snapshot MUST be updated in the same processing flow and remain available as a full snapshot object

#### Scenario: Engineer Mode update refreshes shared snapshot
- **WHEN** Engineer Mode applies a process-parameter change
- **THEN** the shared in-memory `processParameters` snapshot MUST be updated in the same processing flow and remain available as a full snapshot object

#### Scenario: Snapshot read returns complete latest view
- **WHEN** a device message builder requests `processParameters` for serialization
- **THEN** it MUST receive a complete snapshot view representing the latest committed parameter state rather than only incremental deltas
