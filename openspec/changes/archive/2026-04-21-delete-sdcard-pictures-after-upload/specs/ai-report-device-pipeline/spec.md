## ADDED Requirements

### Requirement: Successful ai-report MAY delete source image under shared Pictures

After the Worker returns success for a task and the task-staged directory has been removed, the App SHALL attempt to delete `metadata.json.source_image_absolute_path` when all of the following hold:

- The source path resolves to an existing regular file.
- The canonical source path is either:
  - under existing application-owned roots (`files/cache/no_backup/external-files`), or
  - under the shared Pictures root (`/sdcard/Pictures` canonical-equivalent path).
- The canonical source path is not identical to the task-staged image canonical path.

If deletion fails (I/O error, permission denial, or delete=false), the App SHALL log a warning and SHALL NOT mark the upload task as failed or requeue it solely because of source deletion failure.

#### Scenario: Source in /sdcard/Pictures is deleted after success

- **WHEN** a queued task metadata records `source_image_absolute_path` as `/sdcard/Pictures/a.jpg`
- **AND** `POST /v1/devices/:sn/ai-report` succeeds
- **THEN** the App SHALL delete `/sdcard/Pictures/a.jpg` after task directory cleanup

#### Scenario: Non-Pictures shared path is not deleted

- **WHEN** metadata points to a shared external file outside Pictures (for example `/sdcard/Download/a.jpg`)
- **THEN** the App SHALL NOT delete that file under this capability
