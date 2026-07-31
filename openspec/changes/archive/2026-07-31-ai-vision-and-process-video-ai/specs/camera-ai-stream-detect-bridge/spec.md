## ADDED Requirements

### Requirement: AI Vision live vs weld holder arbitration

When AI Vision live preview requests StreamDetect with `sessionSource: ai_vision_live`, the system SHALL not start if the weld holder (`live_stain_detect`) is already running. When weld starts while AI Vision live was active, weld configuration MUST take priority and prior SSE session stop MAY use `preview_stopped`.

#### Scenario: Weld priority

- **WHEN** weld StreamDetect is running
- **AND** AI Vision live reconcile wants to start
- **THEN** AI Vision live MUST skip starting StreamDetect
