## ADDED Requirements

### Requirement: Enqueue cover after successful local insert when pinned

After a successful process-video insert from Record Work, when Worker API origin is pinned, the App SHALL enqueue cover upload for pending rows (`uploadStatus == 0`). Missing pin MUST NOT fail the local insert.

#### Scenario: Pinned enqueue

- **WHEN** Record Work save inserts a row and pinned origin is available
- **THEN** cover upload for pending rows MUST be scheduled
