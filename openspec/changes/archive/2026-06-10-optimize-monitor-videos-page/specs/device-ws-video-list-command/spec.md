## ADDED Requirements

### Requirement: List response supports client end-of-list pagination

The `command.video_list_response` payload SHALL provide enough pagination information for Monitor -> Videos to decide whether another page is available. The response `data.total` SHALL represent the total count for the active list query, and `data.list` SHALL represent only the requested page window.

#### Scenario: Client computes more pages from total

- **WHEN** Monitor -> Videos receives `command.video_list_response` for a paginated request
- **THEN** the client MUST be able to compare the number of loaded rows with `data.total`
- **AND** the client MUST be able to stop requesting additional pages when the loaded row count is greater than or equal to `data.total`

#### Scenario: Next page appends only requested window

- **WHEN** Monitor -> Videos requests a later page using the same list query
- **THEN** `data.list` MUST contain only rows for that requested page window
- **AND** `data.total` MUST remain the total count for the active query, not the count of the returned page
