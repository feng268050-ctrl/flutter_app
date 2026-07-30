## ADDED Requirements

### Requirement: Monitor Videos tab lists local process recordings

Monitor → Videos SHALL present a table aligned with lws-ui `fragment_process_video` columns: Recording Time, Work Mode, Material, Duration, and Operations. Rows SHALL come from the process-video repository (newest first), not from a directory scan alone. An empty library SHALL show a clear empty state (no crash). Upload actions MUST NOT be offered in this change.

#### Scenario: Populated list shows core columns

- **WHEN** at least one process-video row exists and the operator opens Monitor → Videos
- **THEN** each visible row shows recording time, work mode label, material label (or placeholder), duration, and a Delete control
- **AND** MUST NOT show an active Upload control

#### Scenario: Empty state

- **WHEN** the process-video library is empty
- **THEN** Videos tab shows an empty-state message instead of a stuck loading spinner

#### Scenario: Refresh after new recording

- **WHEN** the operator returns to Videos after a new Record Work save
- **THEN** the new row is visible without requiring an App reinstall (pull-to-refresh or reopen/reload is acceptable)

### Requirement: Videos row opens local detail with playback and parameters

Tapping a Videos row (outside Delete) SHALL open a detail view for that recording. Detail SHALL play the local MP4 when the file is valid, show a parameter panel driven by `process_parameters_json` (with process type / material fallbacks), and provide Back plus Delete. Detail MUST NOT require cloud URLs or upload.

#### Scenario: Local playback

- **WHEN** the operator opens detail for a row whose `video_path` exists and is playable
- **THEN** the detail view presents transport controls and plays the local file

#### Scenario: Parameter panel

- **WHEN** detail opens for a row with a process parameter snapshot
- **THEN** the parameter panel shows at least functional mode and material (when applicable)
- **AND** mode-relevant numeric parameters from the snapshot are visible according to process type

#### Scenario: Missing file soft-fails

- **WHEN** detail opens but the MP4 is missing or unreadable
- **THEN** the UI shows an error/placeholder and remains dismissible without crashing

### Requirement: Monitor Videos supports local delete with confirmation

From the Videos list or detail, Delete SHALL ask for confirmation, then remove the index row and best-effort delete the file, and refresh the list (or pop detail with a result that refreshes).

#### Scenario: Confirm delete from list

- **WHEN** the operator confirms Delete on a list row
- **THEN** that row disappears from Videos
- **AND** the corresponding process-video repository entry is gone

#### Scenario: Cancel delete

- **WHEN** the operator cancels the delete confirmation
- **THEN** the row and file remain unchanged
