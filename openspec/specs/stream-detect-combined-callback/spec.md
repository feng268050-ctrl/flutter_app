# stream-detect-combined-callback Specification

## Purpose
TBD - created by archiving change ai-library-optimization. Update Purpose after archive.
## Requirements
### Requirement: Native stream detect SHALL publish one combined JSON per sampled frame

For each gated detect sample frame, native `stream_detect_event` MUST accumulate results from all enabled modules and publish exactly **one** JNI uplink event containing a combined JSON payload with at minimum `frame_pts_ms` and a `modules` object keyed by module id (e.g. `lens_det`, `zero_point`).

#### Scenario: Single JNI call per sample frame

- **WHEN** lens_det and zero_point are both active and a gated sample completes
- **THEN** native MUST invoke the JNI uplink callback once for that frame
- **AND** MUST NOT invoke separate per-module JNI callbacks for the same frame

#### Scenario: Combined JSON structure

- **WHEN** a combined frame event is published
- **THEN** the JSON MUST include `frame_pts_ms` as an integer millisecond timestamp
- **AND** `modules` MUST contain each completed module's detection JSON under its module key

### Requirement: Per-module JNI callbacks SHALL be deprecated then removed

Legacy per-module `publishDetectResult(module, json)` uplink paths MUST be marked deprecated in Java after the combined callback ships. Per-module native publish MUST be removed after one release cycle once `StreamDetectResultBus` dispatches from combined events.

#### Scenario: Deprecated per-module listener still receives events via bus

- **WHEN** a subscriber registers for per-module `detect_result` on `StreamDetectResultBus`
- **THEN** it MUST receive the module's portion parsed from the combined JSON
- **AND** MUST NOT require a separate native JNI invocation per module

