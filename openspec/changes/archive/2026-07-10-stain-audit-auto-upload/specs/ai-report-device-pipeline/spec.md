## ADDED Requirements

### Requirement: stat.json MAY carry stain audit payload for lens failure reports

When `AiUploadCoordinator.enqueue` is invoked for a `lens` model task produced by the stain audit pipeline, the optional `stat.json` sidecar SHALL contain a JSON object with audit fields separate from `metadata.json`.

For stain audit tasks, `stat.json` SHALL include at minimum:

- `status` — audit status string (V1: `DETECT_FAILED`)
- `reason` — native failure reason token or message
- `source` — detect source (V1: `live_stain_detect`)
- `primary_result` — primary detector outcome label (V1: `DETECT_FAILED`)
- `created_at` — epoch milliseconds

`stat.json` MAY additionally include `frame_id`, `code`, and cluster fields (`cluster_id`, `cluster_hit_frames`, `cluster_cx`, `cluster_cy`, `cluster_area`) when populated by future cluster-audit iterations.

#### Scenario: Enqueued detect-failed task has audit stat

- **WHEN** a Live weld `DETECT_FAILED` sample is enqueued
- **THEN** `tasks/<uuid>/stat.json` SHALL parse as JSON with `status` equal to `DETECT_FAILED`
- **AND** SHALL include `reason` and `source` fields

#### Scenario: metadata.json remains upload contract fields

- **WHEN** a stain audit task is enqueued
- **THEN** `metadata.json` SHALL still contain `sn`, `model`, `type`, and `timestamp_device` per existing ai-report pipeline rules
- **AND** audit-specific fields SHALL NOT replace required metadata fields
