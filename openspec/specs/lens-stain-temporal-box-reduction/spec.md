# lens-stain-temporal-box-reduction Specification

## Purpose
TBD - created by archiving change improve-lens-stain-det-accuracy. Update Purpose after archive.
## Requirements
### Requirement: Process video stain boxes SHALL be reduced temporally at session end

When a `ProcessVideoAiSession` finishes sampling (end-of-file or controlled stop with timeline persist), the system SHALL collect pixel-space detection boxes from all completed timeline frames and SHALL apply temporal reduction before final dirty/clean determination, timeline persist, and summary SSE.

Reduction SHALL use class-level constants on `LensStainBoxTemporalReducer` (or equivalent):

- `BOX_CLUSTER_TOLERANCE_PX` — default **10**; two boxes are considered the same/adjacent when their axis-aligned rectangles expanded by this tolerance (±10 px per edge) intersect.
- `MIN_PERSISTENT_OCCURRENCE_COUNT` — default **3**; a cluster is kept only when its **distinct frame occurrence count** is **greater than or equal to** this value (`count >= MIN_PERSISTENT_OCCURRENCE_COUNT`).

Each timeline frame contributes at most **one** occurrence per cluster even if multiple boxes from the same frame fall into that cluster.

#### Scenario: Fleeting single-frame box is discarded

- **WHEN** a box appears on exactly one sampled frame and no other frame produces a box within tolerance
- **THEN** the reducer MUST NOT include that box in the persistent output
- **AND** final contamination MUST be false

#### Scenario: Stable box across many frames is kept

- **WHEN** boxes at similar locations appear on at least three distinct sampled frames (with default `MIN_PERSISTENT_OCCURRENCE_COUNT = 3`)
- **THEN** the reducer MUST emit one canonical persistent box for that cluster
- **AND** final contamination MUST be true

#### Scenario: Constants are tunable without API change

- **WHEN** engineers change `BOX_CLUSTER_TOLERANCE_PX` or `MIN_PERSISTENT_OCCURRENCE_COUNT` in the reducer class
- **THEN** reduction behavior MUST follow the new constants without changing HTTP routes or SSE event names

### Requirement: Summary frame SHALL be appended to timeline and SSE before stop

After reduction completes, the system SHALL append exactly one **temporal summary** timeline frame containing the persistent boxes (possibly empty), map it to `AiStainDetectResult`, emit **`event: running`** on the session SSE hub, then emit **`event: stop`**.

The summary `running` event MUST use a media-timeline `timestampMs` at or after the last per-sample frame (typically `durationMs`).

#### Scenario: SSE order at session complete

- **WHEN** process video Detect reaches end-of-file and all in-flight infer tasks have completed
- **THEN** subscribers MUST receive a summary `running` event with the reduced boxes
- **AND** MUST receive `stop` with `reason` `session_complete` only after that summary `running`

#### Scenario: Empty reduction yields clean summary

- **WHEN** no cluster exceeds the occurrence threshold
- **THEN** the summary frame MUST contain zero boxes
- **AND** the summary `running` event MUST represent a clean result (no contamination target)

### Requirement: Final contamination and AI Vision alerts SHALL use reduced result only

The system MUST NOT treat per-frame `hasTarget()` alone as the final process-video dirty decision after reduction is implemented. Final dirty/clean for process video Detect completion MUST derive from the temporal summary frame.

For AI Vision, the system SHALL publish at most one `LensCheckResultEvent` per completed Detect session based on the summary result (`level >= 2` when persistent boxes exist, `level == 0` when none).

Production weld **L001** alerts MUST continue to ignore offline stain detect messages per existing `StainDetectAlertMapper.isOfflineStainDetectMessage` rules. Live-weld heavy contamination SHALL trigger immediate L001 presentation per `production-lens-det-dirty-alerts`, not a deferred post-laser-stop queue.

#### Scenario: Detect completes with only fleeting boxes

- **WHEN** several per-frame samples had boxes during Detect but reduction yields zero persistent boxes
- **THEN** the system MUST NOT open a heavy contamination alert dialog for that session
- **AND** replay overlay at end state MUST show no contamination boxes

#### Scenario: Detect completes with persistent boxes

- **WHEN** reduction yields one or more persistent boxes
- **THEN** AI Vision MUST show the summary boxes on completion / replay
- **AND** MUST emit `LensCheckResultEvent` with `level >= 2` once for that session summary

