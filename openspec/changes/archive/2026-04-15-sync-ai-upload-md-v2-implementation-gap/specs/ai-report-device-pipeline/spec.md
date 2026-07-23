## ADDED Requirements

### Requirement: Multipart AI report SHALL include required form fields per upload.md

When the App submits a detection-failure report to `POST /v1/devices/:sn/ai-report`, the request SHALL use `multipart/form-data` and SHALL include at minimum the fields defined in repository `upload.md` section 3.3: path parameter `sn`, and form fields `type`, `image`, `model`, and MAY include `stat` when available.

#### Scenario: Required model field

- **WHEN** the App builds an `ai-report` request for a supported detector
- **THEN** the multipart body SHALL include a `model` field with value `lens` or `metal` as specified in `upload.md`

### Requirement: Local task layout under ai_upload SHALL follow upload.md section 6

When the App persists a pending upload task to private storage, the directory layout SHALL follow `upload.md` section 6 under `/data/data/<package>/files/ai_upload/`, including date hierarchy `yyyy/mm/dd/`, per-model folders (`lens` / `metal`), `tasks/<uuid>/` with `image.jpg`, `metadata.json`, and `state.json`, and `queue/` with pending/uploading/failed queue files as specified.

#### Scenario: Task directory contains required artifacts

- **WHEN** a new upload task is created for model `lens`
- **THEN** the App SHALL create a `tasks/<uuid>/` directory containing the image bytes and JSON sidecars as described in `upload.md` sections 6.2–6.3 and 7

### Requirement: Successful upload SHALL trigger local cleanup per upload.md section 9

After the Worker returns success for a task, the App SHALL delete the corresponding task directory `yyyy/mm/dd/<model>/tasks/<uuid>/` and update queue state as described in `upload.md` section 9, without deleting the entire date directory unless all model tasks under that date are cleared per section 9.3.

#### Scenario: Single task success removes only that task folder

- **WHEN** `ai-report` returns success for task uuid `T`
- **THEN** the App SHALL remove `.../tasks/T/` and SHALL NOT delete the entire `yyyy/mm/dd/` tree unless section 9.3 conditions are met

### Requirement: Normative behavior SHALL be verifiable on the latest integration branch

The behaviors above SHALL be verifiable against `upload.md` on the **latest** App branch that claims `ai-report` support. If a workspace snapshot lacks the client, reviewers SHALL treat that as **checkout lag**, not as proof that the feature is unimplemented upstream.

#### Scenario: Stale workspace does not override repo truth

- **WHEN** local grep finds no `ai-report` symbol but remote main has merged the feature
- **THEN** verification SHALL be re-run after updating the workspace to the latest commit
