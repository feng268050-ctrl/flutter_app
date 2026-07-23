## ADDED Requirements

### Requirement: Worker D1 row metadata aligns with upload.md including model

Documentation and integration reviews SHALL treat `upload.md` section 5.2 as authoritative for D1 fields written by the Worker for `ai-report`, including `model` alongside `sn`, `type`, and `object_key`, consistent with the multipart `model` field in section 3.3.

#### Scenario: Model is persisted server-side

- **WHEN** a successful `ai-report` is processed by the Worker
- **THEN** D1 SHALL be capable of storing the `model` value (`lens` or `metal`) as listed in `upload.md` section 5.2
