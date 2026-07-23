## ADDED Requirements

### Requirement: Optional deletion of original source image after successful ai-report

After the Worker returns success for a task, the App SHALL have completed removal of the task directory per the existing **Successful upload SHALL trigger local cleanup** requirement. Additionally, when the task `metadata.json` contains a non-empty `source_image_absolute_path` field, the App SHALL attempt to delete that path **only if** all of the following hold:

- The path resolves to a regular file that still exists on device.
- The resolved canonical absolute path is under one of the application-owned roots returned by `Context#getFilesDir`, `Context#getCacheDir`, `Context#getNoBackupFilesDir`, or `Context#getExternalFilesDir` (for any supported argument), using canonical path prefix comparison so that `/data/user/0/...` and `/data/data/...` aliases are handled consistently.
- The resolved path is not identical to the task-staged image path for that upload (the copy under `tasks/<uuid>/image.jpg` or its canonical equivalent).

If any condition fails, the App SHALL skip deletion without treating the upload as failed. If deletion throws or returns false, the App SHALL log a warning and SHALL NOT re-queue the upload task solely for deletion failure.

#### Scenario: Source under external files is removed after success

- **WHEN** a task was enqueued with `source_image_absolute_path` set to a JPEG under `Context#getExternalFilesDir` for the hosting application
- **AND** the `ai-report` POST completes with success per existing pipeline rules
- **THEN** the App SHALL delete that source JPEG file after the task directory has been removed

#### Scenario: Gallery path is never deleted

- **WHEN** `source_image_absolute_path` would refer to a file under shared external storage outside `Android/data/<package>/` (for example public `Pictures/` not under app external files)
- **THEN** the App SHALL NOT delete that file even if the field were present (implementation SHOULD omit populating the field for such paths at enqueue time)
