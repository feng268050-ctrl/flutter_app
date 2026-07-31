## MODIFIED Requirements

### Requirement: Monitor Videos tab lists local process recordings

Monitor → Videos SHALL present a table aligned with lws-ui `fragment_process_video` columns: Recording Time, Work Mode, Material, Duration, and Operations. Rows SHALL come from the process-video repository (newest first), not from a directory scan alone. An empty library SHALL show a clear empty state (no crash). Operations SHALL include **Upload**, Details (row open), and Delete. Upload MUST be disabled when `uploadStatus == 3` or when an upload for that row is already in flight. Upload MUST show progress feedback (metadata/cover phase then percent) consistent with lws-ui.

#### Scenario: List shows indexed rows

- **WHEN** at least one process-video row exists and the operator opens Monitor → Videos
- **THEN** the table shows that row's recording time, work mode, material, and duration

#### Scenario: Upload control present

- **WHEN** a row has `uploadStatus` other than `3` and no upload is in flight for it
- **THEN** Videos MUST show an active Upload control for that row

#### Scenario: Empty state

- **WHEN** the process-video library is empty
- **THEN** Videos tab shows an empty-state message instead of a stuck loading spinner

#### Scenario: List refreshes after new save

- **WHEN** the operator returns to Videos after a new Record Work save
- **THEN** the new row appears without requiring an App restart
