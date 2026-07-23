## ADDED Requirements

### Requirement: Lens det results drive overlay geometry without App-side redetection

When lens_det visualization is enabled, the App SHALL map `LensDetDetectResult` to overlay geometry (target point or minimal marker box) for display. The App MUST NOT re-run OpenCV or reinterpret pixels for detection; visualization MUST consume parsed JSON coordinates only.

#### Scenario: Successful target renders marker

- **WHEN** `LensDetDetectResult.success` is true with `targetX` and `targetY` in image pixel space
- **THEN** the overlay layer MUST draw a visible marker at the normalized or pixel-mapped position
- **AND** MUST NOT require RKNN `boxes` or `level` fields

#### Scenario: Failed detect clears or retains hold-forward

- **WHEN** a lens_det sample fails (`success == false`)
- **THEN** live/process-video display MUST retain the previous hold-forward marker until a newer successful sample completes
- **AND** MUST NOT fabricate coordinates

### Requirement: AI Vision live hold-forward for lens det mirrors RKNN unified overlay pattern

When AI Vision live lens_det mode is active, the system SHALL maintain the **latest completed** `LensDetDetectResult` for hold-forward compositing. Composited frames MUST bake the marker into the frame bitmap using the same compositor pipeline as recorded-video Detect (shared renderer), not a separate stacked overlay view as the source of truth.

#### Scenario: Slow lens det keeps previous marker

- **WHEN** sample N is inferring and sample N-1 completed with a target point
- **THEN** composited live frames MUST still show sample N-1 marker until sample N completes

#### Scenario: New lens det result updates following frames

- **WHEN** sample N completes with new `targetX`/`targetY`
- **THEN** subsequent composited frames MUST show the updated marker position

### Requirement: Process video lens det visualization is client-side hold-forward

During `ProcessVideoAiSession`, lens_det overlay for display and LAN HTTP MUST be **client-side hold-forward** from completed `LensDetDetectResult` samples mapped to playback position, matching the non-blocking infer model used for RKNN process-video Detect.

#### Scenario: Playback does not wait for lens det

- **WHEN** the process-video clock advances while lens det infer is in flight
- **THEN** displayed frames MUST use the latest completed lens det result at or before the current playback time
- **AND** MUST NOT block the encode tick waiting for native lens det

### Requirement: Lens det visual style is distinct from RKNN stain level colors

Because lens_det native output does not include stain `level`/`status`, lens_det overlay MUST use a documented neutral or dedicated accent style. The App MUST NOT map lens_det markers to HEAVY/LIGHT/CLEAN colors unless a future spec defines explicit mapping rules.

#### Scenario: No false HEAVY styling

- **WHEN** lens_det visualization is shown
- **THEN** the UI MUST NOT display RKNN HEAVY/MILD/CLEAN badges derived from lens_det coordinates alone
