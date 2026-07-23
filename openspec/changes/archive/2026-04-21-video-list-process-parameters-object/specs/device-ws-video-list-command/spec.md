## MODIFIED Requirements

### Requirement: List item payload minimization

The system SHALL include in each `data.list` element a stable set of fields sufficient to identify and display the video metadata **without** requiring a second round trip for the same row. At minimum the object SHOULD include: `videoId`, `createTime`, `duration`, `fileSize`, `resolution`, `processType`, `materialType`, `uploadStatus`, `uploadProgress`, `coverUrl`, and `videoUrl` when applicable. JSON property names in each `data.list` element SHALL use **camelCase** aligned with `ProcessParamsVideo` / `ProcessParamsVideoVo` field names where those fields exist (for example `videoId`, `createTime`, `uploadStatus`). The system SHALL include **`processParameters`** in each list element as a **JSON object** (parsed from the persisted process-parameters JSON string) or JSON **`null`** when absent, blank, or unparseable. The system SHALL NOT include a string field named `processData` or `process_data` in list elements for this purpose.

#### Scenario: Valid persisted JSON becomes an object

- **WHEN** a list row’s persisted process-parameters string contains valid JSON that parses to a JSON object
- **THEN** the corresponding `data.list` element MUST include `processParameters` as that JSON object and MUST NOT include `processData` / `process_data`

#### Scenario: Absent or invalid JSON becomes null

- **WHEN** the persisted process-parameters string is null, empty, whitespace-only, or does not parse to a JSON object
- **THEN** the corresponding `data.list` element MUST include `processParameters` with JSON value `null`

#### Scenario: Internal storage fields not exposed

- **WHEN** the device serializes each element of `data.list` for `command.video_list_response`
- **THEN** the object MUST NOT include the local database row identifier or local filesystem path fields (for example `id`, `videoPath` / `video_path`)
