## ADDED Requirements

### Requirement: Process video final stain outcome uses temporal reduction

For process video Detect (`StainDetectSource.OFFLINE`), the authoritative dirty/clean outcome for timeline persist, summary SSE, and post-session AI Vision alerts MUST be computed from `LensStainBoxTemporalReducer` output at session end—not from any single per-frame `OpencvStainDetectResult.hasTarget()`.

Per-frame OpenCV calls and `AiStainDetectResult` mapping during sampling MUST remain unchanged for in-progress overlay and per-sample SSE.

#### Scenario: Per-frame target does not imply final dirty

- **WHEN** one sampled frame returns `hasTarget() == true` but temporal reduction yields no persistent boxes
- **THEN** the session summary MUST report clean (no persistent boxes)
- **AND** MUST NOT use that single frame alone as the final dirty verdict

#### Scenario: Summary maps to AiStainDetectResult for SSE

- **WHEN** reduction completes with persistent boxes
- **THEN** the summary `running` payload MUST be an `AiStainDetectResult` derived from the summary frame boxes and dimensions
- **AND** MUST be suitable for `AiInferenceSseJson.runningData`
