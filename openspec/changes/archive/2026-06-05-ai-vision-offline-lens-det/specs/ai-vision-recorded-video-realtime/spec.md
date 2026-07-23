## MODIFIED Requirements

### Requirement: Process video detect includes offline lens_det one-shot

When the user starts **Detect** on a process video and `ENABLE_LENS_DET_APP` is enabled, the system SHALL run OpenCV `lens_det` on each accepted process-video sample in parallel with RKNN stain inference. The App MUST NOT run offline `zero_point` on this path or aggregate offline lens_det into automatic zero correction.

#### Scenario: Detect records stain and lens_det

- **WHEN** Detect is active on a valid recording
- **THEN** timeline samples MUST include RKNN stain results as today
- **AND** MUST additionally record lens_det `targetX`/`targetY` or failure `code` per sample when infer runs

#### Scenario: No Modbus from offline detect

- **WHEN** offline lens_det reports a target offset from a nominal point
- **THEN** `zeroPointCorrection` MUST remain unchanged by this session

### Requirement: Client overlay MAY show lens_det target

The recorded-video overlay pipeline SHOULD render lens_det targets from timeline data after replay, with in-session hold-forward from `ProcessVideoAiSession` as a fallback while Detect is active.

#### Scenario: Hold-forward at playback position

- **WHEN** playback is at `P` and the latest sample at or before `P` has lens_det `success == true`
- **THEN** the UI MUST be able to show the target marker at `(targetX, targetY)`
