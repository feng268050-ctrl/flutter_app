## MODIFIED Requirements

### Requirement: Device users binding probe

The system SHALL call `GET /v1/devices/:sn/users` with the resolved device SN to determine cloud binding state. An empty binding result on success SHALL be treatable as unbound for bind UX. Worker HTTP `401` with `errorCode: INVALID_SN` (or equivalent) SHALL be classified as needs-registration (not unbound). Network failures MUST be structured errors and MUST NOT crash the process.

#### Scenario: Empty users means unbound

- **WHEN** the users endpoint returns success with an empty user set
- **THEN** the App MAY treat the device as unbound for bind prompting

#### Scenario: INVALID_SN means needs registration

- **WHEN** the users endpoint returns HTTP 401 with `INVALID_SN`
- **THEN** the App MUST treat the device as needing registration
- **AND** MUST NOT treat the result as a successful unbound bind state

## ADDED Requirements

### Requirement: Video upload uses STS then metadata

When `command.upload_video` (or LAN equivalent) requests cloud upload, the system SHALL obtain R2 STS credentials, PutObject the media (and cover when required), and register metadata through the Worker video metadata route before acknowledging success to the requester.

#### Scenario: Upload failure is structured

- **WHEN** STS, PutObject, or metadata registration fails
- **THEN** the upload path MUST fail with a structured error or non-success ack
- **AND** MUST NOT terminate the Flutter process
