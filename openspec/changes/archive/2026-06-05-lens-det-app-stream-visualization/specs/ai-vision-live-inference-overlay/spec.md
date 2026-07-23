## ADDED Requirements

### Requirement: AI Vision live supports optional lens det overlay mode

When lens_det visualization is enabled on the AI Vision live tab, the fragment SHALL sample the live preview on the existing 500 ms interval, invoke `inferLensDetFromI420` on a background worker, and update hold-forward lens det overlay state for compositing. This path MUST follow the same non-blocking rules as RKNN unified live infer.

#### Scenario: Lens det live mode does not block TextureView

- **WHEN** lens_det live mode is enabled and a 500 ms sample fires
- **THEN** the main-thread callback MUST return without waiting for lens det native completion

#### Scenario: Lens det overlay uses hold-forward store

- **WHEN** a lens det live sample completes successfully
- **THEN** `AiVisionFragment` MUST update the lens det hold-forward result used by the compositor
- **AND** MUST refresh composited output for subsequent frames

### Requirement: Lens det live overlay coexists with RKNN overlay only when explicitly enabled

By default, enabling lens_det live visualization MUST NOT silently replace RKNN unified overlay unless the operator selects a combined or lens-det-only display mode documented in the UI or feature flag.

#### Scenario: Default RKNN overlay unchanged

- **WHEN** lens_det feature flag is off
- **THEN** AI Vision live overlay behavior MUST match existing RKNN unified requirements without lens det markers
