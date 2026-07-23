## ADDED Requirements

### Requirement: Optional list filters for process type and date range

The system SHALL accept optional filter fields on inbound `command.video_list_request` **`payload`**:

- **`process_type`** (optional integer): when present, restrict rows to those whose `processType` equals this value
- **`start_date`** (optional long, epoch ms): when present, include only rows with `createTime` greater than or equal to this value
- **`end_date`** (optional long, epoch ms): when present, include only rows with `createTime` less than or equal to this value

The system SHALL apply these filters together with the existing **`uploadStatus != 0`** rule when computing **`data.list`** and **`data.total`**. The same filter semantics SHALL be used by the local HTTP **`GET /v1/videos`** endpoint (`processType`, `startDate`, `endDate` query parameters).

#### Scenario: Filtered total matches list

- **WHEN** `command.video_list_request` includes `process_type` and date bounds and matching rows exist
- **THEN** `data.total` MUST equal the count of rows matching all filters, and each `data.list` element MUST satisfy every active filter

#### Scenario: Omitted filters are open-ended

- **WHEN** `command.video_list_request` omits `process_type`, `start_date`, and `end_date`
- **THEN** list behavior MUST match the pre-filter implementation (pagination and `uploadStatus != 0` only)
