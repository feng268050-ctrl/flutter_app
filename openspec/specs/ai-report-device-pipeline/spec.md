## Purpose

Normative App-side behavior for AI detection failure reporting: multipart `POST /v1/devices/:sn/ai-report`, local `files/ai_upload/` layout, queue, and post-success cleanup. Authoritative product detail remains repository `upload.md`; this spec captures acceptance requirements.
## Requirements
### Requirement: Multipart AI report SHALL include required form fields per upload.md

When the App submits a detection-failure report to `POST /v1/devices/:sn/ai-report`, the request SHALL use `multipart/form-data` and SHALL include at minimum the fields defined in repository `upload.md` section 3.3: path parameter `sn`, and form fields `type`, `image`, `model`, and MAY include `stat` when available.

#### Scenario: Required model field

- **WHEN** the App builds an `ai-report` request for a supported detector
- **THEN** the multipart body SHALL include a `model` field with value `lens` or `metal` as specified in `upload.md`

### Requirement: Local task layout under ai_upload SHALL follow upload.md section 6

When the App persists a pending upload task to private storage, the directory layout SHALL follow `upload.md` section 6 under `/data/data/<package>/files/ai_upload/`, including date hierarchy `yyyy/mm/dd/`, per-model folders (`lens` / `metal`), `tasks/<uuid>/` with `image.jpg`, `metadata.json`, and `state.json`, and `queue/` with pending queue files as specified.

#### Scenario: Task directory contains required artifacts

- **WHEN** a new upload task is created for model `lens`
- **THEN** the App SHALL create a `tasks/<uuid>/` directory containing the image bytes and JSON sidecars as described in `upload.md` sections 6.2–6.3 and 7

### Requirement: App-side ai-report uploads SHALL run through persistent WorkManager queue

For device-side product behavior, AI image uploads to `POST /v1/devices/:sn/ai-report` SHALL be initiated by App queue enqueue (`AiUploadCoordinator.enqueue`, `AiUploadPictureDirectoryQueue`, or an equivalent queue API), and the actual HTTP execution SHALL be performed by persistent WorkManager workers. Any direct HTTP call path outside this queue (for example ad-hoc curl/manual POST) SHALL NOT be treated as compliant App pipeline behavior.

#### Scenario: Queue entry drives upload worker

- **WHEN** an AI failure sample is produced by the app pipeline
- **THEN** the App SHALL persist task metadata into the `files/ai_upload/...` queue layout and SHALL rely on WorkManager to execute the upload request

#### Scenario: Manual direct POST is non-normative for app pipeline validation

- **WHEN** a developer manually posts an image to `/v1/devices/:sn/ai-report` outside the App queue path
- **THEN** that request MAY prove network/server reachability but SHALL NOT be accepted as evidence that App queue behaviors such as retry, cleanup, and state transitions are working

### Requirement: Successful upload SHALL trigger local cleanup per upload.md section 9

After the Worker returns success for a task, the App SHALL delete the corresponding task directory `yyyy/mm/dd/<model>/tasks/<uuid>/` and update queue state as described in `upload.md` section 9, without deleting the entire date directory unless all model tasks under that date are cleared per section 9.3.

#### Scenario: Single task success removes only that task folder

- **WHEN** `ai-report` returns success for task uuid `T`
- **THEN** the App SHALL remove `.../tasks/T/` and SHALL NOT delete the entire `yyyy/mm/dd/` tree unless section 9.3 conditions are met

### Requirement: Optional deletion of original source image after successful ai-report

After the Worker returns success for a task, the App SHALL have completed removal of the task directory per the existing **Successful upload SHALL trigger local cleanup** requirement. Additionally, when the task `metadata.json` contains a non-empty `source_image_absolute_path` field, the App SHALL attempt to delete that path **only if** all of the following hold:

- The path resolves to a regular file that still exists on device.
- The resolved canonical absolute path is either:
  - under one of the application-owned roots returned by `Context#getFilesDir`, `Context#getCacheDir`, `Context#getNoBackupFilesDir`, or `Context#getExternalFilesDir` (for any supported argument), using canonical path prefix comparison so that `/data/user/0/...` and `/data/data/...` aliases are handled consistently, or
  - under shared Pictures root (`/sdcard/Pictures`) or canonical equivalent path.
- The resolved path is not identical to the task-staged image path for that upload (the copy under `tasks/<uuid>/image.jpg` or its canonical equivalent).

If any condition fails, the App SHALL skip deletion without treating the upload as failed. If deletion throws or returns false, the App SHALL log a warning and SHALL NOT re-queue the upload task solely for deletion failure.

#### Scenario: Source under external files is removed after success

- **WHEN** a task was enqueued with `source_image_absolute_path` set to a JPEG under `Context#getExternalFilesDir` for the hosting application
- **AND** the `ai-report` POST completes with success per existing pipeline rules
- **THEN** the App SHALL delete that source JPEG file after the task directory has been removed

#### Scenario: Non-Pictures shared path is never deleted

- **WHEN** `source_image_absolute_path` would refer to a file under shared external storage outside `Pictures/` (for example `Download/`)
- **THEN** the App SHALL NOT delete that file even if the field were present (implementation SHOULD omit populating the field for such paths at enqueue time)

#### Scenario: Source under shared Pictures is removed after success

- **WHEN** a queued task metadata records `source_image_absolute_path` as `/sdcard/Pictures/a.jpg`
- **AND** the `ai-report` POST completes with success per existing pipeline rules
- **THEN** the App SHALL delete `/sdcard/Pictures/a.jpg` after the task directory has been removed

### Requirement: Normative behavior SHALL be verifiable on the latest integration branch

The behaviors above SHALL be verifiable against `upload.md` on the **latest** App branch that claims `ai-report` support. If a workspace snapshot lacks the client, reviewers SHALL treat that as **checkout lag**, not as proof that the feature is unimplemented upstream.

#### Scenario: Stale workspace does not override repo truth

- **WHEN** local grep finds no `ai-report` symbol but remote main has merged the feature
- **THEN** verification SHALL be re-run after updating the workspace to the latest commit

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

